import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojian_native_layout/native_layout.dart' as native;
import 'package:bojian_mobile/resume_native_market.dart';

void main() {
  testWidgets('later page background cannot cover the first page', (
    tester,
  ) async {
    ui.Picture page(Color color) {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(color, BlendMode.src);
      return recorder.endRecording();
    }

    final document = native.NativeDocument(
      const Size(100, 100),
      [page(Colors.red), page(Colors.blue)],
      [],
      {},
    );
    final value = NativeMarketDocument(
      native.NativeLayoutRenderer({}, {}, {}),
      document,
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 200,
              height: 400,
              child: NativeMarketPages(value: value),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final first = (50 * image.width + 50) * 4;
      final second = (240 * image.width + 50) * 4;
      expect(pixels.getUint8(first), Colors.red.r * 255);
      expect(pixels.getUint8(first + 2), Colors.red.b * 255);
      expect(pixels.getUint8(second + 2), Colors.blue.b * 255);
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    document.dispose();
    value.renderer.dispose();
  });

  testWidgets(
    'document pans vertically and pinches without a nested scrollable',
    (tester) async {
      ui.Picture page() {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.white, BlendMode.src);
        return recorder.endRecording();
      }

      final document = native.NativeDocument(
        const Size(100, 100),
        List.generate(6, (_) => page()),
        [],
        {},
      );
      final value = NativeMarketDocument(
        native.NativeLayoutRenderer({}, {}, {}),
        document,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 400,
              child: NativeMarketPages(value: value),
            ),
          ),
        ),
      );
      final pages = find.descendant(
        of: find.byType(NativeMarketPages),
        matching: find.byType(CustomPaint),
      );
      final before = tester.getTopLeft(pages.first);
      await tester.dragFrom(const Offset(100, 280), const Offset(0, -130));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(pages.first).dy, lessThan(before.dy - 50));
      final gap =
          tester.getTopLeft(pages.at(1)).dy - tester.getTopLeft(pages.first).dy;
      final a = await tester.startGesture(const Offset(70, 170), pointer: 1);
      final b = await tester.startGesture(const Offset(130, 230), pointer: 2);
      await tester.pump();
      await a.moveTo(const Offset(35, 135));
      await b.moveTo(const Offset(165, 265));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      final enlargedGap =
          tester.getTopLeft(pages.at(1)).dy - tester.getTopLeft(pages.first).dy;
      expect(enlargedGap, greaterThan(gap * 1.3));
      final left = tester.getTopLeft(pages.first).dx;
      await tester.dragFrom(const Offset(140, 200), const Offset(-65, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(pages.first).dx, lessThan(left));
      await tester.pumpWidget(const SizedBox());
      document.dispose();
      value.renderer.dispose();
    },
  );
}
