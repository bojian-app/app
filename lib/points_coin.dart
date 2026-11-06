import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The points coin, drawn in code so every size stays crisp. Shared by the
/// points center and the template market so prices look the same.
class PointsCoin extends StatelessWidget {
  const PointsCoin({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: PointsCoinPainter()),
  );
}

class PointsCoinPainter extends CustomPainter {
  const PointsCoinPainter();

  static final _star = () {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 4.7 : 2.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(12 + math.cos(a) * r, 11.6 + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }();

  /// Paints a 24-unit coin scaled into [rect].
  static void paintCoin(
    Canvas canvas,
    Rect rect, {
    double opacity = 1,
    bool shadow = false,
  }) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 24);
    Color fade(Color color) =>
        color.withValues(alpha: color.a * opacity.clamp(0, 1));
    if (shadow) {
      canvas.drawCircle(
        const Offset(12, 14),
        10.5,
        Paint()
          ..color = fade(const Color(0x590A1E5A))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawCircle(
      const Offset(12, 13),
      10.5,
      Paint()..color = fade(const Color(0xFFD97800)),
    );
    canvas.drawCircle(
      const Offset(12, 11.6),
      10.4,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-.3, -.4),
              radius: .9,
              colors: [
                fade(const Color(0xFFFFF1A8)),
                fade(const Color(0xFFFFC72C)),
                fade(const Color(0xFFF08A00)),
              ],
              stops: const [0, .55, 1],
            ).createShader(
              Rect.fromCircle(center: const Offset(12, 11.6), radius: 10.4),
            ),
    );
    canvas.drawCircle(
      const Offset(12, 11.6),
      7.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = fade(const Color(0xFFFFE68A)),
    );
    canvas.drawPath(_star, Paint()..color = fade(const Color(0xFFF29A00)));
    canvas.save();
    canvas.translate(8.6, 6.6);
    canvas.rotate(-.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 5.2, height: 2.8),
      Paint()..color = fade(Colors.white.withValues(alpha: .6)),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) => paintCoin(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(PointsCoinPainter oldDelegate) => false;
}
