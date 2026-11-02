import 'dart:ui' as ui;

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:bojian_mobile/resume_preview_color.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resume_preview_menu_test.dart' show openPreview, action;
import 'support/fake_gateway.dart';
import 'support/fake_template_webview.dart';

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
    'Native grayscale produces equal RGB channels and retains tonal contrast',
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
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: Colors.red,
                          child: SizedBox.expand(),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: Colors.green,
                          child: SizedBox.expand(),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: Colors.blue,
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
          for (final x in [5, 15, 25, 35]) {
            final offset = (5 * image.width + x) * 4;
            final red = bytes.getUint8(offset);
            expect(bytes.getUint8(offset + 1), closeTo(red, 1));
            expect(bytes.getUint8(offset + 2), closeTo(red, 1));
            expect(bytes.getUint8(offset + 3), 255);
            gray.add(red);
          }
          expect(gray.toSet(), hasLength(4));
          expect(gray.last, 255);
        } finally {
          image.dispose();
        }
      });
    },
  );

  testWidgets('Web template switches in place without reloading its pages', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetResumesId'] = {'revision': 1};
    api.documents['GetResumesIdDomPreview'] = {
      'template_id': 7,
      'html': '<h1 style="color:red">{{name}}</h1>',
      'css': '',
    };
    final store = AppStore(api: api, storage: MemoryStorage());
    await tester.runAsync(() => store.initialize());
    store.session = {'access_token': 'test'};
    addTearDown(store.dispose);
    late FakeTemplateWebView web;
    final resume = ResumeDraft(
      id: 42,
      title: '打印测试',
      revision: 1,
      marketTemplateID: 7,
    );
    store.resumes.add(resume);
    await tester.runAsync(() async {
      web = FakeTemplateWebView()..install();
      await tester.pumpWidget(
        MaterialApp(
          home: ResumePreview(store: store, resumeId: resume.id),
        ),
      );
      await web.loaded.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    final controller = web.controllers.single;
    expect(controller.html, contains('filter:none!important'));
    await action(tester, 'monochrome-preview');
    expect(controller.scripts.last, contains("'grayscale(1)', 'important'"));
    await action(tester, 'monochrome-preview');
    expect(controller.scripts.last, contains("'none', 'important'"));
    expect(controller.loadCount, 1);
    expect(web.controllers, hasLength(1));
    expect(
      tester
          .widget<ResumeMarketDocumentView>(
            find.byType(ResumeMarketDocumentView),
          )
          .monochrome,
      isFalse,
    );
    expect(
      api.calls.where(
        (method) => method.startsWith('Post') || method.startsWith('Patch'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  });
}
