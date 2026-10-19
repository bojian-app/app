import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';

/// One light composition. Only the dolphin, fins, and paper marks move.
class StartupScenePainter extends CustomPainter {
  const StartupScenePainter({
    required this.progress,
    required this.textScaler,
    this.colors = AppColors.light,
  });

  final double progress;
  final TextScaler textScaler;
  final AppColors colors;

  double _phase(double start, double end) =>
      ((progress - start) / (end - start)).clamp(0.0, 1.0);
  double _smooth(double t) => t * t * (3 - 2 * t);

  Paint _fill(Color color) => Paint()
    ..isAntiAlias = true
    ..color = color;
  Paint _stroke(Color color, double width) => _fill(color)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawColor(colors.canvas, BlendMode.src);
    final unit = math.min(size.width / 360, size.height / 440);
    final artScale = .82 * unit;
    final title = TextPainter(
      text: TextSpan(
        text: '博简',
        style: TextStyle(
          fontSize: 30,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: colors.ink,
        ),
      ),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final caption = TextPainter(
      text: TextSpan(
        text: '把繁杂，变简单。',
        style: TextStyle(fontSize: 13, height: 1.5, color: colors.muted),
      ),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final artHeight = 246 * artScale;
    final groupHeight =
        artHeight + 28 * unit + title.height + 10 * unit + caption.height;
    final groupWidth = math.max(
      240 * artScale,
      math.max(title.width, caption.width),
    );
    final fit = math.min(
      1.0,
      math.min(
        math.max(1.0, size.width - 48) / groupWidth,
        math.max(1.0, size.height - 144) / groupHeight,
      ),
    );
    final top = (size.height * .46 - groupHeight * fit / 2)
        .clamp(72.0, math.max(72.0, size.height - 72 - groupHeight * fit))
        .toDouble();
    canvas.save();
    canvas.translate(size.width / 2, top);
    canvas.scale(fit);
    canvas.save();
    canvas.translate(0, 118 * artScale);
    canvas.scale(artScale);
    _dolphin(canvas);
    canvas.restore();
    title.paint(canvas, Offset(-title.width / 2, artHeight + 28 * unit));
    caption.paint(
      canvas,
      Offset(
        -caption.width / 2,
        artHeight + 28 * unit + title.height + 10 * unit,
      ),
    );
    canvas.restore();
    title.dispose();
    caption.dispose();
  }

  void _dolphin(Canvas canvas) {
    final jump = math.sin(math.pi * _phase(.10, .47));
    final prepare = math.sin(math.pi * _phase(0, .18));
    final settle = math.sin(math.pi * _phase(.47, .65));
    final wag = 9 * math.sin(2 * math.pi * _phase(.04, .68));
    final hug = 4 * math.sin(math.pi * _phase(.38, .70));
    final tidy = _smooth(_phase(.28, .60));
    final wink = math.sin(math.pi * _phase(.71, .80));
    final lift = 7 * (1 - _smooth(_phase(0, .12))) - 15 * jump + 2 * settle;

    // A quiet grounding ellipse stays put while the little leap changes its width.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 126),
        width: 130 - 22 * jump,
        height: 9 - 2 * jump,
      ),
      _fill(const Color(0xFFE6EDF6)),
    );
    canvas.save();
    canvas.translate(-3 * jump, lift);
    canvas.rotate(.035 * math.sin(2 * math.pi * _phase(.10, .58)));
    canvas.scale(1 + .022 * prepare, 1 - .035 * prepare);

    final body = Path()
      ..moveTo(-53, -88)
      ..cubicTo(-22, -122, 25, -115, 36, -86)
      ..cubicTo(43, -69, 57, -72, 56, -63)
      ..cubicTo(56, -47, 46, -40, 24, -36)
      ..cubicTo(10, -32, 10, -25, 15, -11)
      ..cubicTo(33, 1, 48, 12, 48, 27)
      ..cubicTo(51, 43, 40, 54, 27, 54)
      ..cubicTo(19, 61, 27, 73, 41, 69)
      ..cubicTo(61, 64, 77, 50, 83 + wag * .35, 15)
      ..cubicTo(86 + wag * .55, 2, 86 + wag, -12, 84 + wag, -29)
      ..cubicTo(84 + wag, -35, 87 + wag, -40, 91 + wag, -35)
      ..cubicTo(126 + wag * .3, 5, 114, 60, 79, 92)
      ..cubicTo(47, 124, -34, 123, -75, 88)
      ..cubicTo(-116, 58, -101, -8, -64, -68)
      ..cubicTo(-80, -89, -69, -106, -53, -88)
      ..close();
    final bodyPaint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF307DFF), Color(0xFF2A5CDA)],
      ).createShader(const Rect.fromLTWH(-108, -116, 228, 234));
    canvas.drawPath(body, bodyPaint);

    // The paper sits inside the C-shaped body, with both fins in front.
    final paper = Path()
      ..moveTo(-46, -34)
      ..lineTo(40, -34)
      ..quadraticBezierTo(49, -34, 49, -24)
      ..lineTo(49, 61)
      ..quadraticBezierTo(49, 67, 41, 69)
      ..cubicTo(7, 74, -20, 61, -42, 41)
      ..quadraticBezierTo(-49, 35, -49, 23)
      ..lineTo(-53, -20)
      ..quadraticBezierTo(-55, -34, -46, -34)
      ..close();
    canvas.drawPath(paper, _fill(const Color(0xFFFFFEF1)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-29, -14, 56, 8),
        const Radius.circular(4),
      ),
      _fill(blue),
    );
    for (var row = 0; row < 2; row++) {
      final shift = (1 - tidy) * (row == 0 ? -7 : 8);
      canvas.save();
      canvas.translate(-27 + shift, 10 + row * 14.0);
      canvas.rotate((1 - tidy) * (row == 0 ? -.10 : .13));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, row == 0 ? 43 : 33, 3),
          const Radius.circular(1.5),
        ),
        _fill(const Color(0xFFB4C8E9)),
      );
      canvas.restore();
    }

    canvas.save();
    canvas.translate(hug * .6, -hug * .2);
    final leftFin = Path()
      ..moveTo(-60, 4)
      ..cubicTo(-40, 13, -23, 22, -22, 33)
      ..cubicTo(-22, 46, -43, 47, -60, 36)
      ..quadraticBezierTo(-66, 23, -60, 4)
      ..close();
    canvas.drawPath(leftFin, bodyPaint);
    canvas.restore();
    canvas.save();
    canvas.translate(-hug * .7, -hug * .2);
    final rightFin = Path()
      ..moveTo(44, -3)
      ..cubicTo(65, 11, 63, 32, 47, 42)
      ..cubicTo(36, 49, 24, 44, 26, 32)
      ..cubicTo(27, 21, 39, 18, 44, -3)
      ..close();
    canvas.drawPath(rightFin, bodyPaint);
    canvas.restore();

    if (wink > .6) {
      final eye = Path()
        ..moveTo(16, -72)
        ..quadraticBezierTo(22, -68, 27, -73);
      canvas.drawPath(eye, _stroke(Colors.white, 2.8));
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(22, -73),
          width: 9.5,
          height: 9.5 * (1 - .7 * wink),
        ),
        _fill(Colors.white),
      );
    }
    canvas.restore();

    // Three short marks react to the leap, then disappear in the same scene.
    final pop = math.sin(math.pi * _phase(.15, .42));
    if (pop > 0) {
      for (var i = 0; i < 3; i++) {
        final start = Offset(-102 + i * 10.0, -90 - i * 12.0);
        canvas.drawLine(
          start,
          start + Offset(-4 * pop, -5 * pop),
          _stroke(const Color(0xFF9EBEF0).withValues(alpha: pop * .7), 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(StartupScenePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.colors != colors;
}
