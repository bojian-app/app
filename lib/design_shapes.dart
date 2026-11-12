import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Hand-drawn marker stroke laid under a heading, traced from the design.
/// It takes the colours of the text it underlines, drawn translucent.
class HighlightScribble extends StatelessWidget {
  const HighlightScribble({
    super.key,
    required this.strokeWidth,
    required this.colors,
  });
  final double strokeWidth;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ScribblePainter(strokeWidth, colors));
}

class _ScribblePainter extends CustomPainter {
  const _ScribblePainter(this.strokeWidth, this.colors);
  final double strokeWidth;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final a = p(0, .7305), b = p(.3140, .0812), c = p(.2576, .9136);
    final d = p(.7872, .4568), e = p(1, .7305);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        a.dx,
        a.dy,
        p(.2295, -.2435).dx,
        p(.2295, -.2435).dy,
        b.dx,
        b.dy,
      )
      ..cubicTo(
        p(.3986, .4058).dx,
        p(.3986, .4058).dy,
        p(.2576, .5565).dx,
        p(.2576, .5565).dy,
        c.dx,
        c.dy,
      )
      ..cubicTo(
        p(.2576, 1.2706).dx,
        p(.2576, 1.2706).dy,
        p(.4167, .4023).dx,
        p(.4167, .4023).dy,
        d.dx,
        d.dy,
      )
      ..cubicTo(p(.8978, .4305).dx, p(.8978, .4305).dy, e.dx, e.dy, e.dx, e.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [
            for (final color
                in colors.length == 1 ? [...colors, ...colors] : colors)
              color.withValues(alpha: .3),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ScribblePainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      !listEquals(oldDelegate.colors, colors);
}

/// Rounds every corner of a polygon the way the design tool does: an arc of
/// [radius] tangent to both edges, shrunk when the edges are too short.
Path roundedPolygon(List<(Offset, double)> corners) {
  final path = Path();
  for (var i = 0; i < corners.length; i++) {
    final (v, radius) = corners[i];
    final a = corners[(i + corners.length - 1) % corners.length].$1;
    final b = corners[(i + 1) % corners.length].$1;
    final ua = (a - v) / (a - v).distance, ub = (b - v) / (b - v).distance;
    final angle = math.acos((ua.dx * ub.dx + ua.dy * ub.dy).clamp(-1.0, 1.0));
    final half = math.tan(angle / 2);
    final cut = math.min(
      radius / half,
      math.min((a - v).distance, (b - v).distance) / 2,
    );
    final start = v + ua * cut, end = v + ub * cut;
    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.arcToPoint(
      end,
      radius: Radius.circular(cut * half),
      clockwise: ua.dx * ub.dy - ua.dy * ub.dx < 0,
    );
  }
  return path..close();
}
