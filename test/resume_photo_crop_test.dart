import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/resume_photo_crop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ui.Image> sourceImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 60, 144),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      const Rect.fromLTWH(60, 0, 60, 144),
      Paint()..color = Colors.blue,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(120, 144);
    } finally {
      picture.dispose();
    }
  }

  test(
    'Moving and resizing crop preserves portrait ratio and image bounds',
    () {
      for (final size in [
        const Size(120, 144),
        const Size(300, 100),
        const Size(20, 80),
      ]) {
        final initial = initialResumePhotoCrop(size);
        expect(initial.width / initial.height, closeTo(5 / 6, .00001));
        for (final rect in [
          initial.shift(const Offset(-500, 1000)),
          const Rect.fromLTWH(1000, -500, 2000, 2400),
          const Rect.fromLTWH(0, 0, 1, 1),
        ]) {
          final crop = constrainResumePhotoCrop(rect, size);
          expect(crop.width / crop.height, closeTo(5 / 6, .00001));
          expect(crop.left, greaterThanOrEqualTo(0));
          expect(crop.top, greaterThanOrEqualTo(0));
          expect(crop.right, lessThanOrEqualTo(size.width + .00001));
          expect(crop.bottom, lessThanOrEqualTo(size.height + .00001));
        }
      }
    },
  );

  test(
    'Encoded photo contains selected pixels rather than original image',
    () async {
      final image = await sourceImage();
      try {
        final file = await writeResumePhotoCrop(
          image,
          const Rect.fromLTWH(80, 48, 40, 48),
        );
        try {
          final codec = await ui.instantiateImageCodec(
            await file.readAsBytes(),
          );
          try {
            final cropped = (await codec.getNextFrame()).image;
            try {
              expect(cropped.width, 40);
              expect(cropped.height, 48);
              final data = await cropped.toByteData();
              expect(data!.buffer.asUint8List().take(4), [33, 150, 243, 255]);
            } finally {
              cropped.dispose();
            }
          } finally {
            codec.dispose();
          }
        } finally {
          await discardResumePhotoCrop(file);
          expect(await File(file.path).exists(), isFalse);
        }
      } finally {
        image.dispose();
      }
    },
  );

  testWidgets('User can drag the crop region and resize with its corner', (
    tester,
  ) async {
    final image = (await tester.runAsync(sourceImage))!;
    Rect? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: ResumePhotoCropCanvas(
              image: image,
              onChanged: (rect) => selected = rect,
            ),
          ),
        ),
      ),
    );
    final area = find.byKey(const ValueKey('resume-photo-crop-area'));
    final before = initialResumePhotoCrop(const Size(120, 144));
    await tester.drag(area, const Offset(-15, 15));
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.center, isNot(before.center));
    expect(selected!.width, closeTo(before.width, .0001));
    final paint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((widget) => widget.painter is ResumePhotoCropPainter);
    final painter = paint.painter as ResumePhotoCropPainter;
    final gesture = await tester.startGesture(
      tester.getTopLeft(area) + painter.crop.bottomRight,
    );
    final priorWidth = selected!.width;
    await gesture.moveBy(const Offset(-40, -48));
    await gesture.moveBy(const Offset(-10, -12));
    await gesture.up();
    await tester.pump();
    expect(selected!.width, lessThan(priorWidth));
    expect(selected!.width / selected!.height, closeTo(5 / 6, .0001));
    await tester.pumpWidget(const SizedBox());
    image.dispose();
  });
}
