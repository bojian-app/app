import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CaptchaChallenge> captchaFixture(
  WidgetTester tester,
) async => (await tester.runAsync(() async {
  Future<String> png(int width, int height) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFE1E8FA),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
  }

  return CaptchaChallenge(
    id: 'captcha-test',
    masterImageDataUrl: await png(320, 180),
    thumbImageDataUrl: await png(44, 44),
    pieceY: 40,
    maxX: 276,
  );
}))!;
