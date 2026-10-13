import 'package:flutter/material.dart';

class CompanyBenefitsArt extends StatelessWidget {
  const CompanyBenefitsArt({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 220,
      height: 152,
      child: CustomPaint(painter: _CompanyBenefitsPainter()),
    ),
  );
}

class _CompanyBenefitsPainter extends CustomPainter {
  const _CompanyBenefitsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 152);
    final paint = Paint()..isAntiAlias = true;
    void rounded(Rect rect, double radius, Color color) {
      paint
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }

    paint.color = const Color(0xFFEDF2FC);
    canvas.drawOval(const Rect.fromLTWH(24, 28, 182, 112), paint);
    rounded(const Rect.fromLTWH(38, 57, 56, 74), 9, const Color(0xFFD6E3FD));
    rounded(const Rect.fromLTWH(157, 70, 33, 61), 7, const Color(0xFFF4DBCD));
    rounded(const Rect.fromLTWH(86, 30, 78, 105), 11, const Color(0xFFE0E8F7));
    rounded(const Rect.fromLTWH(82, 25, 78, 106), 11, Colors.white);
    paint
      ..color = const Color(0xFFABC2F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(82, 25, 78, 106),
        const Radius.circular(11),
      ),
      paint,
    );
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        rounded(
          Rect.fromLTWH(99 + column * 18, 44 + row * 22, 8, 11),
          2.5,
          row == 0 ? const Color(0xFF80A5F3) : const Color(0xFFDCE7FC),
        );
      }
    }
    rounded(const Rect.fromLTWH(115, 112, 13, 19), 4, const Color(0xFFC2D5F9));
    for (var row = 0; row < 3; row++) {
      rounded(
        Rect.fromLTWH(51, 73 + row * 16, 16, 4),
        2,
        const Color(0xFFB3CBF6),
      );
      rounded(
        Rect.fromLTWH(168, 84 + row * 13, 10, 3),
        1.5,
        const Color(0xFFE7BDA5),
      );
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8DAF9F);
    canvas.drawLine(const Offset(48, 131), const Offset(48, 107), paint);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFBCD6C9);
    canvas.drawOval(const Rect.fromLTWH(34, 103, 15, 10), paint);
    canvas.drawOval(const Rect.fromLTWH(48, 112, 14, 9), paint);
    final star = Path()
      ..moveTo(181, 30)
      ..quadraticBezierTo(182, 38, 190, 39)
      ..quadraticBezierTo(182, 40, 181, 48)
      ..quadraticBezierTo(180, 40, 172, 39)
      ..quadraticBezierTo(180, 38, 181, 30)
      ..close();
    paint.color = const Color(0xFFEAC6A8);
    canvas.drawPath(star, paint);
    paint
      ..color = const Color(0xFFDCE4F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawLine(const Offset(24, 132), const Offset(201, 132), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompanyBenefitsPainter oldDelegate) => false;
}
