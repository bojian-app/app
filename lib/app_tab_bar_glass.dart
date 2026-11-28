import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The shape of a pane filling [size].
typedef GlassOutline = Path Function(Size size);

/// A circle cut out of a pane, [centre] being relative to the pane's own.
typedef GlassNotch = ({Offset centre, double radius});

/// A pane of liquid glass: shadow, lens and lit edge along one [outline].
class GlassTabPane extends StatelessWidget {
  const GlassTabPane({
    super.key,
    required this.outline,
    required this.dark,
    required this.frosted,
    required this.child,
    this.notch,
    this.raised = false,
  });
  final GlassOutline outline;
  final bool dark, raised;

  /// Clear glass keeps the page sharp. Frosted glass blurs it and carries more
  /// of its own tone, so icons and labels stay legible over any content.
  final bool frosted;
  final GlassNotch? notch;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ShadowPainter(outline, dark, raised),
    foregroundPainter: _RimPainter(outline, dark),
    child: ClipPath(
      clipper: _OutlineClipper(outline),
      child: _LiquidGlass(
        tint: dark
            ? const Color(0xFF121212).withValues(alpha: frosted ? .55 : .22)
            : Colors.white.withValues(alpha: frosted ? .65 : .30),
        // What the rim mirrors: a pale room in light mode, where white light
        // would vanish against the page, and plain light in dark mode.
        sheen: dark
            ? Colors.white.withValues(alpha: .24)
            : const Color(0xFFBFC7D3).withValues(alpha: .5),
        blur: frosted ? 10 : .5,
        notch: notch,
        child: child,
      ),
    ),
  );
}

class _OutlineClipper extends CustomClipper<Path> {
  const _OutlineClipper(this.outline);
  final GlassOutline outline;

  @override
  Path getClip(Size size) => outline(size);

  @override
  bool shouldReclip(_OutlineClipper oldClipper) =>
      outline != oldClipper.outline;
}

/// Soft shadow around the pane only, so none of it shows through the glass.
/// A [raised] pane casts a deeper one.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.outline, this.dark, this.raised);
  final GlassOutline outline;
  final bool dark, raised;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = outline(size);
    // Glass is drawn by its light; the shadow only lifts it off the page.
    final alpha = raised ? (dark ? .30 : .07) : (dark ? .18 : .035);
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(48)),
          shape,
        ),
      )
      ..drawPath(
        shape.shift(const Offset(0, 8)),
        Paint()
          ..color = Colors.black.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, raised ? 14 : 18),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) =>
      dark != oldDelegate.dark ||
      raised != oldDelegate.raised ||
      outline != oldDelegate.outline;
}

/// The lit edge of the glass: light falls from the top left and leaves at the
/// bottom right.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.outline, this.dark);
  final GlassOutline outline;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = outline(size);
    // Along a wide pane's long axis the light is strongest at the two ends it
    // enters and leaves by, as a -45° source reads on such a shape.
    Shader light(double peak) => ui.Gradient.linear(
      Offset(size.height * .2, 0),
      Offset(size.width - size.height * .2, size.height),
      [
        Colors.white.withValues(alpha: peak),
        Colors.white.withValues(alpha: peak * .22),
        Colors.white.withValues(alpha: peak * .16),
        Colors.white.withValues(alpha: peak * .78),
      ],
      const [0, .3, .72, 1],
    );
    Paint stroke(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    // Only the inner half of each stroke shows.
    canvas
      ..save()
      ..clipPath(shape);
    // The lens lights its rim; this only gives the light a crisp edge.
    canvas
      ..drawPath(shape, stroke(1.2)..shader = light(dark ? .34 : .9))
      ..restore();
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      dark != oldDelegate.dark || outline != oldDelegate.outline;
}

/// Frosts and refracts what is painted beneath [child]. Backends without
/// shader filters (anything but Impeller) get the frost and tint alone.
class _LiquidGlass extends StatefulWidget {
  const _LiquidGlass({
    required this.tint,
    required this.sheen,
    required this.blur,
    required this.notch,
    required this.child,
  });
  final Color tint, sheen;
  final double blur;
  final GlassNotch? notch;
  final Widget child;

  @override
  State<_LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<_LiquidGlass> {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  ui.FragmentShader? shader;

  @override
  void initState() {
    super.initState();
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    if (_program case final program?) {
      shader = program.fragmentShader();
      return;
    }
    (_loading ??= ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass.frag',
    ).then((program) => _program = program)).then((_) {
      if (mounted) setState(() => shader = _program!.fragmentShader());
    }, onError: (_) => _loading = null);
  }

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (shader) {
    final shader? => _Lens(
      shader: shader,
      tint: widget.tint,
      sheen: widget.sheen,
      blur: widget.blur,
      notch: widget.notch,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      // The page's own origin, which stays put while a route slides it.
      origin: Scaffold.maybeOf(context)?.context,
      child: widget.child,
    ),
    null => BackdropFilter(
      filter: ui.ImageFilter.blur(
        sigmaX: 12,
        sigmaY: 12,
        tileMode: TileMode.clamp,
      ),
      child: ColoredBox(color: widget.tint, child: widget.child),
    ),
  };
}

class _Lens extends SingleChildRenderObjectWidget {
  const _Lens({
    required this.shader,
    required this.tint,
    required this.sheen,
    required this.blur,
    required this.notch,
    required this.devicePixelRatio,
    required this.origin,
    required super.child,
  });
  final ui.FragmentShader shader;
  final Color tint, sheen;
  final double blur;
  final GlassNotch? notch;
  final double devicePixelRatio;
  final BuildContext? origin;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLens(shader, tint, sheen, blur, notch, devicePixelRatio, origin);

  @override
  void updateRenderObject(BuildContext context, _RenderLens renderObject) {
    renderObject
      ..shader = shader
      ..tint = tint
      ..sheen = sheen
      ..blur = blur
      ..notch = notch
      ..devicePixelRatio = devicePixelRatio
      ..origin = origin
      ..markNeedsPaint();
  }
}

class _RenderLens extends RenderProxyBox {
  _RenderLens(
    this.shader,
    this.tint,
    this.sheen,
    this.blur,
    this.notch,
    this.devicePixelRatio,
    this.origin,
  );
  ui.FragmentShader shader;
  Color tint, sheen;
  double blur;
  GlassNotch? notch;
  double devicePixelRatio;
  BuildContext? origin;

  // A full dome across the pane's height.
  static const _refraction = 6.0;
  static const _dispersion = .09;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final ancestor = origin?.findRenderObject();
    final center =
        localToGlobal(size.center(Offset.zero), ancestor: ancestor) *
        devicePixelRatio;
    final values = [
      center.dx,
      center.dy,
      size.width / 2 * devicePixelRatio,
      size.height / 2 * devicePixelRatio,
      size.height / 2 * devicePixelRatio,
      // The dome reaches full height at the capsule's long axis.
      size.height / 2 * devicePixelRatio,
      _refraction * devicePixelRatio,
      _dispersion,
      tint.r,
      tint.g,
      tint.b,
      tint.a,
      (notch?.centre.dx ?? 0) * devicePixelRatio,
      (notch?.centre.dy ?? 0) * devicePixelRatio,
      (notch?.radius ?? 0) * devicePixelRatio,
      sheen.r,
      sheen.g,
      sheen.b,
      sheen.a,
    ];
    // The first two floats are the texture size, which the engine fills in.
    for (final (index, value) in values.indexed) {
      shader.setFloat(index + 2, value);
    }
    layer = (layer as BackdropFilterLayer? ?? BackdropFilterLayer())
      ..filter = ui.ImageFilter.compose(
        outer: ui.ImageFilter.shader(shader),
        inner: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.clamp,
        ),
      );
    context.pushLayer(layer!, super.paint, offset);
  }
}
