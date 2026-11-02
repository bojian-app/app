import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_market_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_gateway.dart';
import 'support/fake_template_webview.dart';

class ExportWebView extends FakeTemplateWebView {
  bool failInjection = false;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = ExportWebController(params, this);
    controllers.add(controller);
    return controller;
  }
}

class ExportWebController extends FakeTemplateWebController {
  ExportWebController(super.params, ExportWebView super.owner);

  @override
  Future<void> runJavaScript(String script) async {
    await super.runJavaScript(script);
    if (script.contains('html2canvas 1.4.1') &&
        (owner as ExportWebView).failInjection) {
      throw PlatformException(code: 'injection-failed');
    }
    final mode = RegExp(r'^setResumeExportMode\((true|false),(\d+)\)$')
        .firstMatch(script);
    if (mode != null) {
      message('{"type":"font-ready","token":${mode.group(2)},"count":1}');
    }
    final capture = RegExp(r'^capturePage\(0,(\d+)\)$').firstMatch(script);
    if (capture != null) {
      message('{"type":"page","token":${capture.group(1)},"data":"AQID"}');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late ExportWebView web;
  late GlobalKey<ResumeMarketDocumentViewState> key;

  setUp(() async {
    final api = FakeGateway();
    api.documents['GetResumesId'] = {'revision': 1};
    api.documents['GetResumesIdDomPreview'] = {
      'template_id': 7,
      'html': '<h1>{{name}}</h1>',
      'css': '',
    };
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    web = ExportWebView()..install();
    key = GlobalKey<ResumeMarketDocumentViewState>();
  });
  tearDown(() => store.dispose());

  Future<void> open(WidgetTester tester, {bool monochrome = false}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeMarketDocumentView(
              key: key,
              store: store,
              monochrome: monochrome,
              resume: ResumeDraft(
                id: 1,
                title: '预览测试',
                revision: 1,
                marketTemplateID: 7,
              ),
            ),
          ),
        ),
      );
      await web.loaded.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
  }

  Future<void> export() async {
    final pages = await key.currentState!.capturePages(
      isCancelled: () => false,
      onProgress: (_) {},
    );
    expect(pages.single, [1, 2, 3]);
  }

  testWidgets('Preview omits capture library; repeated exports reuse it', (
    tester,
  ) async {
    await open(tester);
    final controller = web.controllers.single;
    expect(controller.html, isNot(contains('html2canvas 1.4.1')));
    expect(
      controller.scripts.where((s) => s.contains('html2canvas 1.4.1')),
      isEmpty,
    );
    await tester.runAsync(() async {
      await export();
      await export();
    });
    expect(
      controller.scripts.where((s) => s.contains('html2canvas 1.4.1')),
      hasLength(1),
    );
    expect(
      controller.scripts.where((s) => s.startsWith('capturePage(')),
      hasLength(2),
    );
  });

  testWidgets('Failed capture library injection can be retried', (
    tester,
  ) async {
    await open(tester);
    web.failInjection = true;
    await tester.runAsync(() async {
      await expectLater(export(), throwsA(isA<PlatformException>()));
      web.failInjection = false;
      await export();
    });
    expect(
      web.controllers.single.scripts.where(
        (s) => s.contains('html2canvas 1.4.1'),
      ),
      hasLength(2),
    );
  });

  testWidgets(
    'Grayscale preview exports original colors then restores grayscale',
    (tester) async {
      await open(tester, monochrome: true);
      await tester.runAsync(export);
      final scripts = web.controllers.single.scripts;
      final capture = scripts.indexWhere(
        (script) => script.startsWith('capturePage('),
      );
      final filtersBefore = scripts
          .take(capture)
          .where((script) => script.contains("setProperty('filter'"));
      final filtersAfter = scripts
          .skip(capture + 1)
          .where((script) => script.contains("setProperty('filter'"));
      expect(filtersBefore.last, contains("'none', 'important'"));
      expect(filtersAfter.last, contains("'grayscale(1)', 'important'"));
      expect(key.currentState!.widget.monochrome, isTrue);
    },
  );
}
