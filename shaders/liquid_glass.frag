#version 460 core

#include <flutter/runtime_effect.glsl>

// Water drop of the floating tab bar (lib/app_tab_bar.dart): a clear dome
// resting on the page. Beneath its crown the page is magnified; towards the
// rim it is pulled steeply inwards and split slightly by colour. As real
// glass does, the rim is drawn by light rather than shade: seen ever more
// obliquely it reflects ever more of its surroundings, its very edge catches
// the light from the top left where it faces it and where it leaves, and that
// light gathers into a soft crescent on the far side. There is deliberately no
// specular glint: it read as a stray dot beside the first tab.
// A circle may be notched out of the shape.
// All lengths are in physical pixels of the backdrop texture.
uniform vec2 uSize;      // Set by the engine: size of the backdrop texture.
uniform vec2 uCenter;    // Centre of the capsule.
uniform vec2 uHalf;      // Half of its width and height.
uniform float uRadius;
uniform float uDepth;      // Distance from the rim at which the dome is full.
uniform float uRefraction; // How far the page shifts under the dome's slope.
uniform float uDispersion; // Red and blue offsets relative to green.
uniform vec4 uTint;        // Straight alpha.
uniform vec3 uNotch;       // Centre relative to uCenter, radius (0 for none).
uniform vec4 uSheen;       // Colour of the surroundings the rim reflects, and
                           // how strongly it does at the very edge.
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 backdrop(vec2 position) {
  vec2 uv = clamp(position / uSize, vec2(0.0), vec2(1.0));
// Same compensation as shaders/print_gray.frag.
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
}

// Slope of a circular dome profile at [distance] inside an edge: steep at
// the edge, flat from uDepth inwards.
float slope(float distance) {
  float u = 1.0 - clamp(distance / uDepth, 0.0, 1.0);
  return min(u / max(sqrt(max(1.0 - u * u, 0.0)), 0.0001), 3.2);
}

void main() {
  vec2 position = FlutterFragCoord().xy;
  vec2 p = position - uCenter;
  vec2 q = abs(p) - uHalf + uRadius;
  float rim = uRadius - length(max(q, vec2(0.0))) - min(max(q.x, q.y), 0.0);
  vec2 away = p - uNotch.xy;
  float hole = uNotch.z > 0.0 ? length(away) - uNotch.z : 2.0 * uDepth;
  float s = min(rim, hole);
  if (s <= 0.0) {
    fragColor = backdrop(position);
    return;
  }
  // Each edge slopes the dome on its own and the two add up: no crease where
  // they meet, and on the narrow strip under the notch they cancel into a
  // flat ridge instead of bending the page in an arbitrary direction.
  vec2 side = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
  vec2 corner = max(q, vec2(0.0));
  vec2 outward = side * (dot(corner, corner) > 0.0
      ? normalize(corner)
      : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0)));
  vec2 tilt = -outward * slope(rim)
      // Pushed away from the notch, the page must not be sampled from beyond
      // the far rim of the narrow strip beneath it.
      + away / max(length(away), 0.0001)
          * min(slope(hole), 0.75 * rim / (uRefraction * (1.0 + uDispersion)));
  tilt *= min(1.0, 3.2 / max(length(tilt), 0.0001));

  // A convex lens magnifies: every point samples nearer to the crown, and
  // ever more so towards the rim.
  vec2 offset = tilt * uRefraction;
  vec3 color = vec3(
    backdrop(position + offset * (1.0 - uDispersion)).r,
    backdrop(position + offset).g,
    backdrop(position + offset * (1.0 + uDispersion)).b);
  color = mix(color, uTint.rgb, uTint.a);

  float t = clamp(s / uDepth, 0.0, 1.0);
  // Fresnel: the steeper the surface, the more it mirrors its surroundings.
  float fresnel = pow(1.0 - t, 5.0);
  // The edge itself: bright arcs where it faces the light and opposite it.
  vec2 surfaceOut = -tilt / max(length(tilt), 0.0001);
  float facing = abs(dot(surfaceOut, normalize(vec2(-0.55, -0.8))));
  float edgeLight = smoothstep(0.08, 0.0, t) * (0.2 + 0.8 * pow(facing, 3.0));
  // Light passing through gathers on the side facing away from it.
  float gather = clamp(dot(tilt, normalize(vec2(-0.55, -0.8))), 0.0, 1.0);
  float caustic = gather * smoothstep(0.0, 0.1, t) * smoothstep(0.45, 0.1, t);

  color = mix(color, uSheen.rgb, fresnel * uSheen.a);
  color += caustic * 0.12;
  color += vec3(edgeLight * 0.55);
  fragColor = vec4(min(color, vec3(1.0)), 1.0);
}
