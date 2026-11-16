#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uTexture;

out vec4 fragColor;

// Same tone curve as printedLightness in lib/resume_preview_color.dart.
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
// Flutter 3.47+ stores GLES render targets top-down, like Metal and Vulkan.
// Only older GLES engines need this compensation; applying it twice flips
// the resume vertically on devices using the GLES backend.
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  vec4 color = texture(uTexture, uv);
  if (color.a <= 0.0) {
    fragColor = color;
    return;
  }
  float ink = 1.0 - dot(color.rgb / color.a, vec3(0.299, 0.587, 0.114));
  ink = (ink + 0.6 * ink * (1.0 - ink)) * smoothstep(0.03, 0.08, ink);
  fragColor = vec4(vec3(1.0 - ink) * color.a, color.a);
}
