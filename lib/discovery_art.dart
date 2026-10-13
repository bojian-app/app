import 'package:flutter/material.dart';

import 'design.dart';

enum DiscoveryScene { resume, community, search }

class DiscoveryArt extends StatelessWidget {
  const DiscoveryArt({
    super.key,
    required this.scene,
    this.width = 144,
    this.height = 120,
  });

  final DiscoveryScene scene;
  final double width, height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _DiscoveryPainter(scene)),
      ),
    ),
  );
}

class _DiscoveryPainter extends CustomPainter {
  const _DiscoveryPainter(this.scene);
  final DiscoveryScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 144, size.height / 120);
    final paint = Paint();
    void box(Rect rect, Color color, [double radius = 8]) {
      paint.color = color;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }

    void line(Offset start, Offset end, Color color, [double width = 3]) {
      paint
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
      paint.style = PaintingStyle.fill;
    }

    paint.color = const Color(0xFFDCE7F7);
    canvas.drawOval(const Rect.fromLTWH(15, 106, 118, 9), paint);
    if (scene == DiscoveryScene.resume) {
      canvas.save();
      canvas.translate(58, 59);
      canvas.rotate(-.16);
      box(const Rect.fromLTWH(-35, -47, 70, 96), const Color(0xFFCBDCF8));
      canvas.restore();
      box(const Rect.fromLTWH(39, 8, 72, 101), Colors.white);
      paint.color = const Color(0xFFDDEAFF);
      canvas.drawCircle(const Offset(58, 29), 9, paint);
      line(const Offset(77, 25), const Offset(98, 25), blue, 4);
      line(
        const Offset(77, 33),
        const Offset(93, 33),
        const Color(0xFFB7C8E3),
        2,
      );
      for (var i = 0; i < 3; i++) {
        final y = 50.0 + i * 17;
        line(Offset(51, y), Offset(72, y), blue.withValues(alpha: .6), 3);
        line(Offset(51, y + 7), Offset(98, y + 7), const Color(0xFFE0E7F1), 2);
      }
      canvas.save();
      canvas.translate(118, 54);
      canvas.rotate(.35);
      box(const Rect.fromLTWH(-4, 0, 8, 46), const Color(0xFFE9B971), 3);
      box(const Rect.fromLTWH(-4, 0, 8, 8), const Color(0xFFF6DAB1), 3);
      paint.color = const Color(0xFF4E6585);
      canvas.drawPath(
        Path()
          ..moveTo(-4, 46)
          ..lineTo(4, 46)
          ..lineTo(0, 55)
          ..close(),
        paint,
      );
      canvas.restore();
      paint.color = const Color(0xFF73B7A2);
      canvas.drawCircle(const Offset(105, 97), 16, paint);
      line(const Offset(98, 97), const Offset(103, 102), Colors.white, 3);
      line(const Offset(103, 102), const Offset(113, 91), Colors.white, 3);
    } else {
      box(const Rect.fromLTWH(45, 15, 77, 56), const Color(0xFFCAE4DD), 12);
      paint.color = const Color(0xFFCAE4DD);
      canvas.drawPath(
        Path()
          ..moveTo(104, 68)
          ..lineTo(114, 81)
          ..lineTo(116, 66)
          ..close(),
        paint,
      );
      box(const Rect.fromLTWH(17, 41, 89, 61), Colors.white, 12);
      paint.color = Colors.white;
      canvas.drawPath(
        Path()
          ..moveTo(28, 97)
          ..lineTo(29, 111)
          ..lineTo(45, 99)
          ..close(),
        paint,
      );
      line(
        const Offset(32, 58),
        const Offset(71, 58),
        blue.withValues(alpha: .7),
      );
      line(const Offset(32, 70), const Offset(90, 70), const Color(0xFFDDE7F5));
      line(const Offset(32, 82), const Offset(75, 82), const Color(0xFFDDE7F5));
      if (scene == DiscoveryScene.search) {
        paint
          ..color = blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
        canvas.drawCircle(const Offset(99, 74), 20, paint);
        paint.style = PaintingStyle.fill;
        line(const Offset(114, 89), const Offset(130, 105), blue, 7);
      } else {
        for (var i = 0; i < 3; i++) {
          paint.color = const Color(0xFF73B7A2);
          canvas.drawCircle(Offset(65.0 + i * 16, 32), 3, paint);
        }
      }
    }
    line(
      const Offset(15, 21),
      const Offset(15, 31),
      const Color(0xFFE2B778),
      2,
    );
    line(
      const Offset(10, 26),
      const Offset(20, 26),
      const Color(0xFFE2B778),
      2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiscoveryPainter oldDelegate) =>
      scene != oldDelegate.scene;
}
