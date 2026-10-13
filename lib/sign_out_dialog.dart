import 'package:flutter/material.dart';

import 'design.dart';

Future<bool?> showSignOutDialog(BuildContext context) =>
    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭退出登录确认',
      barrierColor: ink.withValues(alpha: .32),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (_, animation, _, child) {
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: .94, end: 1).animate(curve),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, _) => Dialog(
        key: const ValueKey('sign-out-dialog'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFE9EFFB)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(
                  child: SizedBox(
                    width: 112,
                    height: 90,
                    child: CustomPaint(painter: _LittleNotePainter()),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '确定要退出登录么？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('我再看看'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('confirm-sign-out'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('狠心离开'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

/// A small folded note with a face, drawn once without an image or looping ticker.
class _LittleNotePainter extends CustomPainter {
  const _LittleNotePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      const Rect.fromLTWH(23, 76, 66, 7),
      fill..color = blue.withValues(alpha: .07),
    );
    canvas.save();
    canvas.translate(56, 42);
    canvas.rotate(-.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-29, -31, 58, 64),
        const Radius.circular(15),
      ),
      fill..color = const Color(0xFFEDF3FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-29, -31, 58, 64),
        const Radius.circular(15),
      ),
      pen
        ..color = const Color(0xFFC2D5FC)
        ..strokeWidth = 1.5,
    );
    final fold = Path()
      ..moveTo(12, -31)
      ..lineTo(12, -19)
      ..quadraticBezierTo(12, -14, 17, -14)
      ..lineTo(29, -14);
    canvas.drawPath(fold, pen..color = const Color(0xFFC2D5FC));
    canvas.drawOval(
      const Rect.fromLTWH(-16, 3, 10, 6),
      fill..color = const Color(0xFFF8BFC7),
    );
    canvas.drawOval(const Rect.fromLTWH(8, 3, 10, 6), fill);
    pen
      ..color = const Color(0xFF4C6594)
      ..strokeWidth = 2.8;
    canvas.drawLine(const Offset(-10, -6), const Offset(-10, -2), pen);
    canvas.drawLine(const Offset(12, -6), const Offset(12, -2), pen);
    final mouth = Path()
      ..moveTo(-3, 9)
      ..quadraticBezierTo(1, 6, 5, 9);
    canvas.drawPath(mouth, pen..strokeWidth = 1.8);
    canvas.drawLine(
      const Offset(-28, 11),
      const Offset(-37, 5),
      pen
        ..color = const Color(0xFF9CBDF8)
        ..strokeWidth = 3,
    );
    canvas.drawLine(const Offset(28, 10), const Offset(37, 0), pen);
    canvas.restore();
    canvas.drawCircle(
      const Offset(13, 27),
      3,
      fill..color = const Color(0xFFF8D89A),
    );
    canvas.drawCircle(
      const Offset(99, 65),
      2.5,
      fill..color = const Color(0xFFC2D5FC),
    );
    pen
      ..color = const Color(0xFF9CBDF8)
      ..strokeWidth = 1.8;
    canvas.drawLine(const Offset(94, 15), const Offset(94, 23), pen);
    canvas.drawLine(const Offset(90, 19), const Offset(98, 19), pen);
  }

  @override
  bool shouldRepaint(_LittleNotePainter oldDelegate) => false;
}
