import 'dart:io';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/template_live_preview.dart';
import 'package:bojian_mobile/template_preview_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_gateway.dart';
import 'support/fake_template_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway api;
  late AppStore store;
  late FakeTemplateWebView web;
  setUp(() async {
    api = FakeGateway();
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    api.documents['GetTemplatesIdDom'] = {
      'template_id': 7,
      'version': 3,
      'html': '<h1>{{name}}</h1><p>{{position}}</p>',
      'css': 'h1{color:#2867ee}',
    };
    web = FakeTemplateWebView()..install();
  });
  tearDown(() => store.dispose());

  Future<void> open(
    WidgetTester tester, {
    ValueChanged<int>? onOpenPage,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: TemplateLivePreview(
              store: store,
              templateID: 7,
              version: 3,
              author: '模板作者 A',
              onOpenPage: onOpenPage,
            ),
          ),
        ),
      );
      await web.loaded.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Native page actions stay outside zoom content and open the selected page',
    (tester) async {
      int? selected;
      await open(tester, onOpenPage: (page) => selected = page);
      final controller = web.controllers.single;
      controller.message(
        '{"type":"page-actions","items":[{"index":0,"top":0,"bottom":0.48},{"index":1,"top":0.52,"bottom":1}]}',
      );
      await tester.pump();
      final first = find.byKey(const ValueKey('preview-page-action-0'));
      final second = find.byKey(const ValueKey('preview-page-action-1'));
      final originalSize = tester.getSize(first);
      final originalRight = tester.getTopRight(first).dx;
      expect(second, findsOneWidget);
      await tester.tap(second);
      await tester.pump();
      expect(selected, 1);
      expect(controller.scripts, contains('window.openPreviewPage?.(1);'));
      // At zoomed viewport bounds only one page fills the screen. Native action
      // geometry stays unchanged while the document's visible bounds change.
      controller.message(
        '{"type":"page-actions","items":[{"index":0,"top":0,"bottom":1}]}',
      );
      await tester.pump();
      expect(tester.getSize(first), originalSize);
      expect(tester.getTopRight(first).dx, originalRight);
      expect(second, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('live-template-webview')),
          matching: first,
        ),
        findsNothing,
      );
      expect(controller.loadCount, 1);
      expect(web.controllers, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Live DOM uses sample data, per-page author watermark and blocks external navigation',
    (tester) async {
      await open(tester);
      expect(api.calls, contains('GetTemplatesIdDom'));
      expect(api.calls, isNot(contains('GetTemplatesIdPreviewAssets')));
      expect(
        find.byKey(const ValueKey('live-template-webview')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2 页简历预览，作者水印：模板作者 A'), findsOneWidget);
      final controller = web.controllers.single;
      expect(controller.html, contains('林晓'));
      expect(controller.html, isNot(contains('测试账号')));
      expect(controller.html, contains("img-src data:"));
      expect(
        await controller.navigation!.request!(
          const NavigationRequest(
            url: 'https://example.com',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await controller.navigation!.request!(
          NavigationRequest(
            url: Uri.file(controller.filePath!).toString(),
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
    },
  );

  testWidgets(
    'Renderer failure retries with DOM and logout hides preview and ignores late callbacks',
    (tester) async {
      await open(tester);
      web.controllers.single.message(
        '{"type":"error","message":"render failed"}',
      );
      await tester.pumpAndSettle();
      expect(find.text('重新加载预览'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('重新加载预览'));
        for (var i = 0; i < 100 && web.controllers.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 页简历预览，作者水印：模板作者 A'), findsOneWidget);
      expect(api.calls.where((c) => c == 'GetTemplatesIdDom'), hasLength(2));
      store.epoch++;
      store.changed();
      web.controllers.last.message('{"type":"ready","count":4}');
      await tester.pumpAndSettle();
      expect(find.text('登录状态已变化，请返回后重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-template-webview')), findsNothing);
      expect(find.bySemanticsLabel('4 页简历预览，作者水印：模板作者 A'), findsNothing);
    },
  );

  testWidgets('Changed template version does not display a stale preview', (
    tester,
  ) async {
    api.documents['GetTemplatesIdDom']!['version'] = 4;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemplateLivePreview(
              store: store,
              templateID: 7,
              version: 3,
              author: '作者',
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('模板已更新，请刷新详情'), findsOneWidget);
    expect(web.controllers, isEmpty);
  });

  test('Preview fixture shares renderer and has responsive live pages without capture library', () async {
    final renderer = File('assets/templates/market_renderer.js')
        .readAsStringSync();
    final html = templatePreviewDocument(
      dom: {
        'html':
            '<h1>{{name}}</h1><p>{{position}}</p><p>{{phone}} · {{email}}</p>'
            '<p>{{#work_experiences}}</p><h2>{{title}}</h2><p>{{detail}}</p><p>{{/work_experiences}}</p>'
            '${List.filled(24, '<p>项目经验与工作成果，展示真实排版与多页阅读。项目经验与工作成果，展示真实排版与多页阅读。</p>').join()}',
        'css': '@page{margin:16mm}h1{color:#2867ee;font-size:32px}h2{font-size:20px}p{font-size:16px;line-height:1.7;margin:14px 0}',
      },
      rendererScript: renderer,
      previewScript: File('assets/templates/market_preview.js')
          .readAsStringSync(),
    );
    expect(html, contains(renderer));
    expect(html, contains('width=device-width'));
    expect(html, isNot(contains('html2canvas 1.')));
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/template-live-qa.html').writeAsString(html);
    for (final font in templatePreviewFontAssets.entries) {
      await File(font.value).copy('build/previews/${font.key}');
    }
  });
}
