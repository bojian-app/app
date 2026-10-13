import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/captcha_dialog.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<String> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return Uri.dataFromBytes(
    Uint8List.sublistView(bytes!),
    mimeType: 'image/png',
  ).toString();
}

void main() {
  testWidgets('Landscape puzzle and slider fit without scrolling or cropping', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(792, 360);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    final store = await testStore();
    final master = await tester.runAsync(() => png(320, 180));
    final piece = await tester.runAsync(() => png(44, 44));
    final challenge = CaptchaChallenge(
      id: 'layout-test',
      masterImageDataUrl: master!,
      thumbImageDataUrl: piece!,
      pieceY: 80,
      maxX: 276,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CaptchaDialog(
                  store: store,
                  challenge: challenge,
                  phone: '13812345678',
                ),
              ),
              child: const Text('打开验证'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开验证'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    for (final size in [const Size(792, 360), const Size(640, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final image = tester.getRect(find.byKey(const ValueKey('captcha-image')));
      final slider = tester.getRect(
        find.byKey(const ValueKey('captcha-slider')),
      );
      final scroll = find.descendant(
        of: find.byType(CaptchaDialog),
        matching: find.byType(Scrollable),
      );
      final viewport = tester.getRect(scroll);
      expect(image.height / image.width, closeTo(180 / 320, .001));
      expect(image.top, greaterThanOrEqualTo(viewport.top));
      expect(image.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(slider.top, greaterThanOrEqualTo(viewport.top));
      expect(slider.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(slider.left, greaterThan(image.right));
      expect(tester.state<ScrollableState>(scroll).position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptchaDialog), findsNothing);
  });
}
