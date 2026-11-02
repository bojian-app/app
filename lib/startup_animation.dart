import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';

/// Entirely local, and played only once per cold start.
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
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else if (controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.canvas,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            label: '博简，让每一份精彩，被看见。正在准备应用',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    height: 250,
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => CustomPaint(
                        painter: _WelcomePainter(
                          progress: controller.value,
                          dark: Theme.of(context).brightness == Brightness.dark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '博简',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: context.colors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '让每一份精彩，被看见',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 2,
                      color: context.colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomePainter extends CustomPainter {
  const _WelcomePainter({required this.progress, required this.dark});
  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(math.min(size.width / 260, size.height / 250));
    final paint = Paint();
    final t = Curves.easeInOutCubic.transform(progress);
    final bounce = math.sin(progress * math.pi * 2) * (1 - progress);
    paint.color = blue.withValues(alpha: dark ? .14 : .06);
    canvas.drawCircle(Offset.zero, 104, paint);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * .4 - .4;
      final radius = 90 + math.sin(progress * math.pi) * 12;
      final point = Offset(math.cos(angle), math.sin(angle)) * radius;
      paint
        ..color = (i.isEven ? blue : const Color(0xFFFFBE66)).withValues(
          alpha: .65,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        point - const Offset(3, 0),
        point + const Offset(3, 0),
        paint,
      );
      canvas.drawLine(
        point - const Offset(0, 3),
        point + const Offset(0, 3),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    paint.color = blue.withValues(alpha: .08);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 88),
        width: 100 - bounce * 10,
        height: 12,
      ),
      paint,
    );
    canvas.save();
    canvas.translate(-6, -bounce * 12);
    canvas.rotate(-.08 + bounce * .06);
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-51, -67, 102, 138),
      const Radius.circular(17),
    );
    canvas.drawShadow(
      Path()..addRRect(card),
      blue.withValues(alpha: .2),
      12,
      false,
    );
    paint.color = dark ? const Color(0xFF25344B) : Colors.white;
    canvas.drawRRect(card, paint);
    paint.color = blue.withValues(alpha: .12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-35, -51, 70, 53),
        const Radius.circular(10),
      ),
      paint,
    );
    final blink = (progress - .42).abs() < .045;
    paint
      ..color = dark ? const Color(0xFF97B9FF) : blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final x in [-13.0, 13.0]) {
      if (blink) {
        canvas.drawLine(Offset(x - 3, -31), Offset(x + 3, -31), paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, -31), width: 5, height: 8),
          paint,
        );
      }
    }
    paint.style = PaintingStyle.stroke;
    canvas.drawArc(
      const Rect.fromLTWH(-10, -27, 20, 16),
      .2,
      math.pi - .4,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      paint.color = blue.withValues(alpha: i == 0 ? .5 : .15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-32, 17 + i * 14, i == 2 ? 36 : 64, 5),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    canvas.restore();
    final plane = Offset(30 + 49 * t, 32 - 100 * t);
    paint.color = blue.withValues(alpha: .22);
    for (var i = 0; i < 7; i++) {
      final u = t * i / 8;
      canvas.drawCircle(
        Offset(30 + 49 * u, 32 - 100 * u + math.sin(u * math.pi) * 15),
        2,
        paint,
      );
    }
    canvas.save();
    canvas.translate(plane.dx, plane.dy);
    canvas.rotate(-.25 - t * .15);
    paint.color = blue;
    canvas.drawPath(
      Path()
        ..moveTo(-25, -9)
        ..lineTo(25, -21)
        ..lineTo(6, 24)
        ..lineTo(-3, 5)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFF9BBFFF);
    canvas.drawPath(
      Path()
        ..moveTo(-3, 5)
        ..lineTo(25, -21)
        ..lineTo(1, 12)
        ..close(),
      paint,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WelcomePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
