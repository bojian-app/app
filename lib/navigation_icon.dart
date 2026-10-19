import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original 32-unit tab icons: shared rounded strokes and blue filled states.
class NavigationIcon extends StatelessWidget {
  const NavigationIcon({
    super.key,
    required this.index,
    required this.progress,
    required this.color,
  });
  final int index;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: CustomPaint(painter: _NavigationPainter(index, progress, color)),
  );
}

class _NavigationPainter extends CustomPainter {
  const _NavigationPainter(this.index, this.progress, this.color);
  final int index;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF72B2FF).withValues(alpha: progress),
          const Color(0xFF2867EE).withValues(alpha: progress),
        ],
      ).createShader(const Rect.fromLTWH(2, 2, 28, 28));
    final detail = Paint()
      ..color = Color.lerp(color, Colors.white, progress)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void shape(Path path) {
      canvas.drawPath(path, body);
      canvas.drawPath(path, stroke);
    }

    Path round(
      double left,
      double top,
      double width,
      double height,
      double radius,
    ) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          Radius.circular(radius),
        ),
      );

    switch (index) {
      case 0:
        // A softly squared compass with a floating north star.
        shape(round(4, 5, 24, 24, 10));
        final needle = Path()
          ..moveTo(20.9, 11.1)
          ..lineTo(18.2, 20.2)
          ..lineTo(10.9, 22.1)
          ..lineTo(13.6, 13)
          ..close();
        canvas.drawPath(
          needle,
          Paint()
            ..color = Color.lerp(Colors.transparent, Colors.white, progress)!,
        );
        canvas.drawPath(needle, detail);
        canvas.drawLine(
          const Offset(14, 13.4),
          const Offset(18, 19.8),
          Paint()
            ..color = Color.lerp(color, const Color(0xFF2867EE), progress)!
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round,
        );
        _sparkle(canvas, const Offset(25.5, 5.5), 4.2, progress);
      case 1:
        // One centered layout card, with a header and two content columns.
        shape(round(5, 3, 22, 26, 5));
        canvas.drawLine(const Offset(10, 9), const Offset(22, 9), detail);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 13, 5, 10),
            const Radius.circular(1.5),
          ),
          detail,
        );
        canvas.drawLine(const Offset(19, 14), const Offset(22, 14), detail);
        canvas.drawLine(const Offset(19, 18), const Offset(22, 18), detail);
        canvas.drawLine(const Offset(19, 22), const Offset(22, 22), detail);
      case 2:
        // One centered star coin with no offset or duplicate silhouette.
        shape(round(3.5, 3.5, 25, 25, 12.5));
        final star = _star(const Offset(16, 16), 7, 3.5);
        canvas.drawPath(
          star,
          Paint()
            ..color = Color.lerp(Colors.transparent, Colors.white, progress)!,
        );
        canvas.drawPath(star, detail);
      default:
        // Friendly profile badge: a rounded silhouette, never a copied mascot.
        final profile = Path()
          ..moveTo(16, 3)
          ..cubicTo(24, 3, 28, 8, 28, 16)
          ..lineTo(28, 21)
          ..quadraticBezierTo(28, 29, 20, 29)
          ..lineTo(12, 29)
          ..quadraticBezierTo(4, 29, 4, 21)
          ..lineTo(4, 16)
          ..cubicTo(4, 8, 8, 3, 16, 3)
          ..close();
        shape(profile);
        canvas.drawCircle(const Offset(16, 12), 4, detail);
        canvas.drawPath(
          Path()
            ..moveTo(9, 24)
            ..cubicTo(9, 17.5, 23, 17.5, 23, 24),
          detail,
        );
        _sparkle(canvas, const Offset(27, 5), 3.6, progress);
    }
  }

  Path _star(Offset center, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? outer : inner;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  void _sparkle(Canvas canvas, Offset center, double radius, double alpha) {
    if (alpha == 0) return;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + .8,
        center.dy - .8,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + .8,
        center.dy + .8,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - .8,
        center.dy + .8,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - .8,
        center.dy - .8,
        center.dx,
        center.dy - radius,
      );
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF8DD9FF).withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_NavigationPainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}
