import 'dart:io';
import 'dart:convert';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_native_market.dart';
import 'package:bojian_mobile/template_live_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/fake_gateway.dart';

class PreviewPaths extends PathProviderPlatform {
  PreviewPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
}

void main() {
  testWidgets(
    'market native preview skips WebView and retains device font and author',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('native-preview-');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = PreviewPaths(directory.path);
      final api = FakeGateway();
      final store = AppStore(api: api, storage: MemoryStorage());
      await tester.runAsync(store.initialize);
      store.session = {'access_token': 'fixture'};
      store.userID = 12;
      api.documents['GetTemplatesIdDom'] = {
        'template_id': 4,
        'version': 1,
        'html': '<h1>fallback</h1>',
        'schema': {
          'native': {
            'assets': {
              'paper': base64Encode(
                utf8.encode(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1" fill="white"/></svg>',
                ),
              ),
            },
            'layout': {
              'format': 'bojian-native-layout',
              'schemaVersion': '1.0',
              'page': {
                'size': {'width': 794, 'height': 1123},
                'contentPadding': {
                  'top': 20,
                  'bottom': 20,
                  'left': 20,
                  'right': 20,
                },
                'background': {
                  'color': '#FFFFFF',
                  'asset': 'paper',
                  'fit': 'fill',
                },
              },
              'assets': {
                'paper': {'type': 'svg'},
              },
              'textStyles': {
                'body': {
                  'fontSizePt': 10,
                  'lineHeight': 1.5,
                  'color': '#000000',
                },
              },
              'sections': [
                for (final id in [
                  'personal_info',
                  'job_expectation',
                  'self_evaluation',
                  'work_experiences',
                  'projects',
                  'educations',
                  'skills',
                  'certifications',
                ])
                  {
                    'id': id,
                    'type': 'column',
                    'padding': {'top': 8, 'bottom': 8},
                    'children': [
                      {'type': 'text', 'text': id, 'textStyle': 'body'},
                    ],
                  },
              ],
            },
          },
        },
      };
      Widget preview(String author) => MaterialApp(
        home: Scaffold(
          body: TemplateLivePreview(
            store: store,
            templateID: 4,
            version: 1,
            author: author,
          ),
        ),
      );
      try {
        await tester.pumpWidget(preview('作者甲'));
        // Real asset decoding and cache I/O must run outside the fake clock.
        for (
          var i = 0;
          i < 100 && find.byType(NativeMarketPages).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(
          find.byType(NativeMarketPages),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        expect(find.byType(WebViewWidget), findsNothing);
        expect(tester.takeException(), isNull);
        final first = tester.widget<NativeMarketPages>(
          find.byType(NativeMarketPages),
        );
        expect(first.value.renderer.useSystemFont, isTrue);
        expect(first.watermark, '作者甲');
        expect(
          api.calls.where((call) => call == 'GetTemplatesIdDom'),
          hasLength(1),
        );
        await tester.pumpWidget(preview('作者乙'));
        final updated = tester.widget<NativeMarketPages>(
          find.byType(NativeMarketPages),
        );
        expect(identical(first.value, updated.value), isTrue);
        expect(updated.watermark, '作者乙');
        // Account changes must remove the old account's prepared document.
        store.epoch++;
        store.notifyListeners();
        await tester.pump();
        expect(find.byType(NativeMarketPages), findsNothing);
        expect(find.text('登录状态已变化，请返回后重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        PathProviderPlatform.instance = originalPaths;
        directory.deleteSync(recursive: true);
      }
    },
  );
}
