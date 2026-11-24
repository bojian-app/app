import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

class InvitationQrPainter extends CustomPainter {
  InvitationQrPainter(String value)
    : image = QrImage(
        QrCode.fromData(data: value, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
  final QrImage image;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final cell = size.shortestSide / (image.moduleCount + 8);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH((col + 4) * cell, (row + 4) * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(InvitationQrPainter old) => old.image != image;
}

Future<Uint8List> createInvitationQrPng({
  required String code,
  required String link,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(960, 1200);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEEECFF), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size),
  );
  void write(String value, double y, double fontSize, Color color) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'ResumeDocument',
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    )..layout(maxWidth: 880);
    painter.paint(canvas, Offset((size.width - painter.width) / 2, y));
  }

  write('邀请你加入最优简', 55, 56, const Color(0xFF182A96));
  write('扫码下载，注册后填写邀请码', 145, 33, const Color(0xFF535B8C));
  canvas.save();
  canvas.translate(100, 220);
  InvitationQrPainter(link).paint(canvas, const Size(760, 760));
  canvas.restore();
  write('邀请码：$code', 1010, 48, const Color(0xFF182A96));
  write('一起制作好简历', 1110, 30, const Color(0xFF535B8C));
  final picture = recorder.endRecording();
  final image = await picture.toImage(960, 1200);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
