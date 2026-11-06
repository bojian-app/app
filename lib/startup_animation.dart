import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design.dart';

/// How long the cold-start welcome plays; startup waits at least this long.
const startupAnimationDuration = Duration(milliseconds: 1600);

/// Entirely local, and played only once per cold start: the app icon's otter
/// leaps out of the water, lands with a splash, blinks and writes the line on
/// its resume.
class StartupAnimation extends StatefulWidget {
  const StartupAnimation({super.key, this.animate = true});
  final bool animate;

  @override
  State<StartupAnimation> createState() => _StartupAnimationState();
}

class _StartupAnimationState extends State<StartupAnimation>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: startupAnimationDuration,
  );
  ImageStream? stream;
  ImageInfo? otter;
  late final listener = ImageStreamListener((info, _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      otter?.dispose();
      otter = info;
    });
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = const ResizeImage(
      AssetImage('assets/branding/app_icon.png'),
      width: 512,
    ).resolve(createLocalImageConfiguration(context));
    if (next.key != stream?.key) {
      stream?.removeListener(listener);
      stream = next..addListener(listener);
    }
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else if (controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    stream?.removeListener(listener);
    otter?.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const otterSize = 168.0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: '博简，正在准备应用',
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final t = controller.value;
                  final title = Curves.easeOutCubic.transform(
                    _segment(t, .66, .88),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: otterSize * 1.62,
                        child: CustomPaint(
                          painter: _WaterOtterPainter(
                            progress: t,
                            otter: otter?.image,
                            otterSize: otterSize,
                            dark: dark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: title,
                        child: Transform.translate(
                          offset: Offset(0, (1 - title) * 10),
                          child: Text(
                            '博简',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: context.colors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _segment(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

double _easeInOutCubic(double t) => Curves.easeInOutCubic.transform(t);

double _easeOutCubic(double t) => Curves.easeOutCubic.transform(t);

/// Closing eyelid: 0 open, 1 shut, over a 10% slice of the timeline.
double _blinkAt(double t, double start) {
  final p = _segment(t, start, start + .1);
  return p <= 0 || p >= 1 ? 0 : math.sin(p * math.pi);
}

class _WaterOtterPainter extends CustomPainter {
  const _WaterOtterPainter({
    required this.progress,
    required this.otter,
    required this.otterSize,
    required this.dark,
  });
  final double progress;
  final ui.Image? otter;
  final double otterSize;
  final bool dark;

  // Colours and positions sampled from assets/branding/app_icon.png, in its
  // 1024-pixel space, so the blink and line overlays sit exactly on the icon.
  static const _eye = Offset(520.5, 234.2);
  static const _bodyNearEye = Color(0xFF2871F4);
  static const _lineStart = 409.5, _lineEnd = 559.5, _lineY = 484.0;
  static const _lineColor = Color(0xFF2E5FDC);
  static const _card = Color(0xFFFFFEEF);
  static const _splash = Color(0xFF5B92FF);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final s = otterSize;
    final cx = size.width / 2;
    final rest = s * .9;
    final water = rest + s * .30;

    _paintWater(canvas, size, water, t);

    // Leap: rise with a stretch, overshoot, fall, squash on landing, then bob.
    var y = rest, sx = 1.0, sy = 1.0;
    final top = rest - s * .32, start = rest + s;
    if (t < .40) {
      final rise = _segment(t, .12, .40);
      final e = _easeOutCubic(rise);
      y = start + (top - start) * e;
      if (rise > 0) {
        sy = 1 + .14 * (1 - e);
        sx = 1 - .08 * (1 - e);
      }
    } else if (t < .58) {
      final fall = _segment(t, .40, .58);
      final e = fall * fall;
      y = top + (rest - top) * e;
      sy = 1 + .06 * e;
      sx = 1 - .04 * e;
    } else {
      final settle = _segment(t, .58, .78);
      final k = math.exp(-settle * 4) * math.cos(settle * 12);
      sy = 1 - .12 * k;
      sx = 1 + .09 * k;
    }
    y += math.sin(t * 7) * 2 * _segment(t, .7, 1);
    final centre = Offset(cx, y + s * (1 - sy) / 2);
    final blink = _blinkAt(t, .74);
    final write = _easeInOutCubic(_segment(t, .80, .96));

    // Above the surface the otter is solid; just below it shows faintly.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, water));
    _paintOtter(canvas, centre, sx, sy, blink, write, 1);
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, water, size.width, water + s * .36));
    _paintOtter(canvas, centre, sx, sy, blink, write, .22);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, water));
    _paintDrops(canvas, cx, water, t, .16, 7, 1);
    _paintDrops(canvas, cx, water, t, .56, 5, .55);
    canvas.restore();
    for (final ring in const [.16, .56, .62]) {
      final p = _segment(t, ring, ring + .45);
      if (p <= 0 || p >= 1) continue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, water + 2),
          width: s * (.3 + p * .55) * 2,
          height: (6 + p * 8) * 2,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _splash.withValues(alpha: (1 - p) * .55),
      );
    }
  }

  void _paintWater(Canvas canvas, Size size, double water, double t) {
    final appear = _easeOutCubic(_segment(t, 0, .15));
    if (appear <= 0) return;
    double waveY(double x) =>
        water + math.sin(x / 22 + t * 9) * 3 * appear + (1 - appear) * 30;
    final surface = Path()..moveTo(0, waveY(0));
    for (var x = 4.0; x <= size.width + 4; x += 4) {
      surface.lineTo(x, waveY(x));
    }
    final depth = water + 70;
    final body = Path.from(surface)
      ..lineTo(size.width + 4, depth)
      ..lineTo(0, depth)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            blue.withValues(alpha: (dark ? .30 : .16) * appear),
            blue.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(0, water - 4, size.width, water + 64)),
    );
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _splash.withValues(alpha: .55 * appear),
    );
  }

  void _paintDrops(
    Canvas canvas,
    double cx,
    double water,
    double t,
    double start,
    int count,
    double power,
  ) {
    final p = _segment(t, start, start + .28);
    if (p <= 0 || p >= 1) return;
    final paint = Paint()..color = _splash.withValues(alpha: 1 - p);
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (i - (count - 1) / 2) * .38;
      final speed = power * (.8 + (i % 3) * .15);
      final dx = math.cos(angle) * speed * p * otterSize * .98;
      final dy =
          math.sin(angle) * speed * p * otterSize +
          p * p * otterSize * .89;
      canvas.drawCircle(
        Offset(cx + dx, water + dy),
        4.5 - (i % 2) * 1.5,
        paint,
      );
    }
  }

  void _paintOtter(
    Canvas canvas,
    Offset centre,
    double sx,
    double sy,
    double blink,
    double write,
    double alpha,
  ) {
    final image = otter;
    if (image == null) return;
    final s = otterSize;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(sx, sy);
    canvas.translate(-s / 2, -s / 2);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.black.withValues(alpha: alpha),
    );
    canvas.scale(s / 1024);
    if (write < 1) {
      // Hide the icon's line, then draw it growing left to right.
      canvas.drawRect(
        Rect.fromLTRB(_lineStart - 20, _lineY - 20, _lineEnd + 20, _lineY + 20),
        Paint()..color = _card.withValues(alpha: alpha),
      );
      if (write > 0) {
        canvas.drawLine(
          const Offset(_lineStart, _lineY),
          Offset(_lineStart + (_lineEnd - _lineStart) * write, _lineY),
          Paint()
            ..color = _lineColor.withValues(alpha: alpha)
            ..strokeWidth = 29
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (blink > 0) {
      canvas.drawCircle(
        _eye,
        21,
        Paint()..color = _bodyNearEye.withValues(alpha: alpha),
      );
      final white = Colors.white.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: _eye,
          width: 32,
          height: math.max(32 * (1 - blink), .2),
        ),
        Paint()..color = white,
      );
      if (blink > .6) {
        canvas.drawArc(
          Rect.fromCircle(center: _eye - const Offset(0, 6), radius: 14),
          math.pi * .15,
          math.pi * .7,
          false,
          Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WaterOtterPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.otter != otter ||
      oldDelegate.otterSize != otterSize ||
      oldDelegate.dark != dark;
}
