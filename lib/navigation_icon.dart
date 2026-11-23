import 'package:flutter/material.dart';

import 'app_theme.dart';

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
    child: CustomPaint(
      painter: _NavigationPainter(
        index,
        progress,
        color,
        context.colors.palette,
      ),
    ),
  );
}

class _NavigationPainter extends CustomPainter {
  const _NavigationPainter(this.index, this.progress, this.color, this.palette);
  final AppAccent palette;
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
        stops: const [0, .59, 1],
        colors: [
          (palette == AppAccent.blue
                  ? const Color(0xFF72B2FF)
                  : const Color(0xFFFFAE89))
              .withValues(alpha: progress),
          (palette == AppAccent.blue
                  ? const Color(0xFF4A8BF7)
                  : const Color(0xFFEE7972))
              .withValues(alpha: progress),
          palette.seed.withValues(alpha: progress),
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
        // A softly squared compass.
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
            ..color = Color.lerp(color, palette.seed, progress)!
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round,
        );
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
        // A cushion-cut gem with a broad table and two readable facets.
        final gem = Path()
          ..moveTo(10, 6)
          ..lineTo(22, 6)
          ..quadraticBezierTo(23, 6, 23.6, 6.8)
          ..lineTo(28, 12.5)
          ..quadraticBezierTo(28.8, 13.6, 27.9, 14.7)
          ..lineTo(17.2, 27)
          ..quadraticBezierTo(16, 28.4, 14.8, 27)
          ..lineTo(4.1, 14.7)
          ..quadraticBezierTo(3.2, 13.6, 4, 12.5)
          ..lineTo(8.4, 6.8)
          ..quadraticBezierTo(9, 6, 10, 6)
          ..close();
        canvas.drawPath(gem, body);
        canvas.save();
        canvas.clipPath(gem);
        canvas.drawLine(const Offset(3, 13.5), const Offset(29, 13.5), detail);
        canvas.drawPath(
          Path()
            ..moveTo(11, 13.5)
            ..lineTo(16, 27.7)
            ..lineTo(21, 13.5),
          detail,
        );
        canvas.restore();
        canvas.drawPath(gem, stroke);
      case 4:
        // A speech bubble with a tail and three dots: online support.
        shape(
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(4, 5, 24, 18),
                const Radius.circular(8),
              ),
            )
            ..moveTo(10, 22)
            ..lineTo(9, 28)
            ..lineTo(16, 23)
            ..close(),
        );
        for (final x in [11.0, 16.0, 21.0]) {
          canvas.drawLine(Offset(x, 14), Offset(x + .1, 14), detail);
        }
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
    }
  }

  @override
  bool shouldRepaint(_NavigationPainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.palette != palette;
}
