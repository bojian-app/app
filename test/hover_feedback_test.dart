import 'dart:ui' as ui;

import 'package:bojian_mobile/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [appTheme, appDarkTheme]) {
    testWidgets('Hover does not paint a background (${theme.brightness})', (
      tester,
    ) async {
      var taps = 0;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (_, child) =>
              RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            body: Material(
              child: Column(
                children: [
                  InkWell(
                    onTap: () => taps++,
                    child: const SizedBox(
                      width: 300,
                      height: 50,
                      child: Text('文章内容'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('默认按钮'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red)
                        .withoutHover(),
                    onPressed: () => taps++,
                    child: const Text('自定义按钮'),
                  ),
                  IconButton(
                    onPressed: () => taps++,
                    icon: const Icon(Icons.add),
                  ),
                  Checkbox(value: false, onChanged: (_) => taps++),
                  ChoiceChip(
                    label: const Text('筛选'),
                    selected: false,
                    onSelected: (_) => taps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> pixels() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return bytes!.buffer.asUint8List().toList();
        }))!;
      }

      final baseline = await pixels();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(790, 590));
      for (final finder in [
        find.byType(InkWell).first,
        find.text('默认按钮'),
        find.text('自定义按钮'),
        find.byType(IconButton),
        find.byType(Checkbox),
        find.byType(ChoiceChip),
      ]) {
        await mouse.moveTo(tester.getCenter(finder));
        await tester.pumpAndSettle();
        expect(await pixels(), baseline, reason: '$finder changes on hover');
      }
      await mouse.removePointer();
      await tester.tap(find.text('文章内容'));
      await tester.tap(find.text('自定义按钮'));
      expect(taps, 2);
    });
  }
}
