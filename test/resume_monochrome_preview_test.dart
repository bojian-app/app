import 'dart:ui' as ui;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_preview_color.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resume_preview_menu_test.dart' show openPreview, action;
import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Menu toggles existing preview without navigation or losing document and zoom',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      final resume = ResumeDraft(id: 42, title: '打印测试');
      store.resumes.add(resume);
      await openPreview(tester, store);
      final state = tester.state<ResumeDocumentViewState>(
        find.byType(ResumeDocumentView),
      );
      final route = ModalRoute.of(
        tester.element(find.byType(ResumeDocumentView)),
      );
      final document = state.document;
      state.transform.value = Matrix4.diagonal3Values(1.5, 1.5, 1);
      await action(tester, 'monochrome-preview');
      expect(
        tester
            .widget<ResumePreviewColor>(find.byType(ResumePreviewColor))
            .monochrome,
        isTrue,
      );
      expect(tester.state(find.byType(ResumeDocumentView)), same(state));
      expect(
        ModalRoute.of(tester.element(find.byType(ResumeDocumentView))),
        same(route),
      );
      expect(state.document, same(document));
      expect(state.transform.value.entry(0, 0), 1.5);
      await tester.tap(find.byKey(const ValueKey('resume-more')));
      await tester.pumpAndSettle();
      expect(find.text('彩色预览'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('resume-action-monochrome-preview')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ResumePreviewColor>(find.byType(ResumePreviewColor))
            .monochrome,
        isFalse,
      );
      expect(tester.state(find.byType(ResumeDocumentView)), same(state));
      expect(state.transform.value.entry(0, 0), 1.5);
      expect(store.resumes.single, same(resume));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ResumePreview), findsNothing);
      expect(find.text('简历列表'), findsOneWidget);
    },
  );

  testWidgets(
    'Native grayscale preserves quadrant orientation and tonal contrast',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: const ResumePreviewColor(
                monochrome: true,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: ColoredBox(
                                color: Color(0xFFFF0000),
                                child: SizedBox.expand(),
                              ),
                            ),
                            Expanded(
                              child: ColoredBox(
                                color: Color(0xFF00FF00),
                                child: SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: ColoredBox(
                                color: Color(0xFF0000FF),
                                child: SizedBox.expand(),
                              ),
                            ),
                            Expanded(
                              child: ColoredBox(
                                color: Colors.white,
                                child: SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final gray = <int>[];
          for (final (x, y) in [(10, 10), (30, 10), (10, 30), (30, 30)]) {
            final offset = (y * image.width + x) * 4;
            final red = bytes.getUint8(offset);
            expect(bytes.getUint8(offset + 1), closeTo(red, 1));
            expect(bytes.getUint8(offset + 2), closeTo(red, 1));
            expect(bytes.getUint8(offset + 3), 255);
            gray.add(red);
          }
          expect(gray.toSet(), hasLength(4));
          // Unequal rows and columns expose vertical flips and mirroring.
          expect(gray[1], greaterThan(gray[0]));
          expect(gray[0], greaterThan(gray[2]));
          expect(gray.last, 255);
        } finally {
          image.dispose();
        }
      });
    },
  );
}
