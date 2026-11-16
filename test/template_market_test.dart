import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/template_market.dart';
import 'package:bojian_mobile/template_market_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/fake_template_webview.dart';

import 'package:bojian_mobile/template_live_preview.dart';

class MarketGateway extends FakeGateway {
  final requests =
      <
        ({
          String method,
          Map<String, String> query,
          Map<String, dynamic>? body,
          Map<String, String> headers,
        })
      >[];
  Completer<ApiDocument>? delayed;
  final held = <String, Completer<ApiDocument>>{};
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (failing == method) {
      throw const ApiFailure('服务器暂不可用');
    }
    requests.add((method: method, query: query, body: body, headers: headers));
    if (held.containsKey(method)) return held.remove(method)!.future;
    if (method == 'GetTemplates' && delayed != null) {
      final waiting = delayed!;
      delayed = null;
      return waiting.future;
    }
    if (method == 'GetTemplates') {
      return ApiDocument(
        documents[method] ?? {'items': []},
        nextCursor: documents[method]?['next_cursor'] as String? ?? '',
      );
    }
    if (method == 'PostTemplatesIdAcquisitions') {
      calls.add(method);
      documents['GetMeTemplates'] = {
        'items': [
          ...?documents['GetMeTemplates']?['items'] as List?,
          {'id': 7, 'name': '商务设计', 'source': 'ACQUIRED'},
        ],
      };
      return ApiDocument({'acquired': true});
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MarketGateway api;
  late AppStore store;
  late TemplateMarketStore market;
  late FakeTemplateWebView preview;
  Future<void> settlePreview(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pump();
      await preview.loaded.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
  }

  setUp(() async {
    api = MarketGateway();
    preview = FakeTemplateWebView()..install();
    api.documents['GetTemplatesIdDom'] = {
      'template_id': 7,
      'version': 1,
      'html': '<h1>{{name}}</h1>',
      'css': '',
    };
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    market = TemplateMarketStore(store);
    api.documents['GetTemplatesId'] = {
      'id': 7,
      'name': '商务设计',
      'price_points': 80,
      'pricing_type': 'PAID',
      'revision': 3,
      'version': 1,
      'compatible': true,
      'status': 'PUBLISHED',
    };
  });
  tearDown(() {
    market.dispose();
    store.dispose();
  });
  for (final waitingMethod in ['GetMeTemplates']) {
    testWidgets(
      'Preview does not wait for $waitingMethod, purchase stays disabled',
      (tester) async {
        final waiting = Completer<ApiDocument>();
        api.held[waitingMethod] = waiting;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme,
              home: TemplateMarketDetail(
                market: market,
                template: {'id': 7},
                onUseTemplate: (_, _) {},
              ),
            ),
          );
          await tester.pump();
          await preview.loaded.future.timeout(const Duration(seconds: 5));
        });
        await tester.pump();
        expect(waiting.isCompleted, isFalse);
        expect(find.byType(TemplateLivePreview), findsOneWidget);
        expect(preview.controllers.single.html, contains('林晓'));
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.runAsync(() async {
          waiting.complete(ApiDocument({'items': []}));
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('Search and pricing persist across cursor pagination, duplicate IDs excluded', () async {
    market.query = '设计';
    market.filter = TemplateMarketFilter.paid;
    api.documents['GetTemplates'] = {
      'items': [
        {'id': 7, 'name': '第一页'},
      ],
      'next_cursor': 'cursor-a',
    };
    await market.load();
    api.documents['GetTemplates'] = {
      'items': [
        {'id': 7, 'name': '重复项'},
        {'id': 8, 'name': '第二页'},
      ],
    };
    await market.load(more: true);
    expect(market.templates.map((row) => row['id']), [7, 8]);
    expect(api.requests.last.query, {
      'limit': '24',
      'query': '设计',
      'pricing': 'PAID',
      'cursor': 'cursor-a',
    });
  });
  test('Slow old search never overwrites the newest results', () async {
    final old = Completer<ApiDocument>();
    api.delayed = old;
    final first = market.load();
    await Future<void>.delayed(Duration.zero);
    api.documents['GetTemplates'] = {
      'items': [
        {'id': 8, 'name': '新结果'},
      ],
    };
    market.search('新', immediately: true);
    await Future<void>.delayed(Duration.zero);
    old.complete(
      ApiDocument({
        'items': [
          {'id': 7, 'name': '旧结果'},
        ],
      }),
    );
    await first;
    expect(market.templates.single['name'], '新结果');
  });
  test('My templates contains acquisitions only, and retains no unowned catalogue items', () async {
    api.documents['GetMeTemplates'] = {
      'items': [
        {'id': 7, 'name': '已获取', 'source': 'ACQUIRED'},
      ],
    };
    await market.loadOwned();
    market.select(TemplateMarketFilter.owned);
    expect(market.visible.map((row) => row['id']), [7]);
  });
  test(
    'Acquisition binds the quoted revision and skips owned templates',
    () async {
      await market.acquire(id: 7, quotedRevision: 3);
      expect(market.ownedIDs, {7});
      expect(
        api.calls.where((call) => call == 'PostTemplatesIdAcquisitions').length,
        1,
      );
      await market.acquire(id: 7, quotedRevision: 3);
      expect(
        api.calls.where((call) => call == 'PostTemplatesIdAcquisitions').length,
        1,
      );
    },
  );
  test('Changed revision and failed ownership check prevent any acquisition request', () async {
    api.documents['GetTemplatesId']!['revision'] = 4;
    await expectLater(
      market.acquire(id: 7, quotedRevision: 3),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, isNot(contains('PostTemplatesIdAcquisitions')));
    api.failing = 'GetMeTemplates';
    await expectLater(
      market.acquire(id: 7, quotedRevision: 4),
      throwsA(isA<ApiFailure>()),
    );
    expect(api.calls, isNot(contains('PostTemplatesIdAcquisitions')));
  });
  test(
    'Logout clears private ownership and prevents subsequent acquisition',
    () async {
      api.documents['GetMeTemplates'] = {
        'items': [
          {'id': 7, 'name': '已获取', 'source': 'ACQUIRED'},
        ],
      };
      await market.loadOwned();
      store.epoch++;
      store.changed();
      expect(market.owned, isEmpty);
      expect(market.valid, isFalse);
      await expectLater(
        market.acquire(id: 7, quotedRevision: 3),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, isNot(contains('PostTemplatesIdAcquisitions')));
    },
  );
  testWidgets(
    'Market uses actual preview cards, supports filters and landscape layout',
    (tester) async {
      api.documents['GetTemplates'] = {
        'items': [
          {
            'id': 7,
            'name': '商务设计',
            'price_points': 80,
            'preview_status': 'PENDING',
          },
        ],
      };
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: TemplateMarketView(store: store, onUseTemplate: (_, _) {}),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      // Cards show only the page preview; name and price live on the detail page.
      final card = find.byType(MarketTemplateArtwork);
      expect(card, findsOneWidget);
      expect(find.text('预览生成中'), findsOneWidget);
      expect(find.text('好设计，让重点自然被看见。'), findsNothing);
      expect(find.byType(SliverGrid), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final searchRect = tester.getRect(find.byType(TextField));
      expect(searchRect.left, appPageHorizontalPadding);
      expect(390 - searchRect.right, appPageHorizontalPadding);
      expect(tester.getTopLeft(find.text('模板市场')).dx, appPageHorizontalPadding);
      expect(tester.getTopLeft(card).dx, appPageHorizontalPadding);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Horizontal swipes switch market filters and respect edges', (
    tester,
  ) async {
    Future<void> drain() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: TemplateMarketView(store: store, onUseTemplate: (_, _) {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await drain();
    final area = find.byKey(const ValueKey('template-market-swipe'));
    Future<void> swipe(double dx) async {
      await tester.drag(
        area,
        Offset(dx.sign * tester.getSize(area).width * .75, 0),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await drain();
    }

    TabController controller() => tester.widget<TabBarView>(area).controller!;
    int selected() => controller().index;
    final gesture = await tester.startGesture(tester.getCenter(area));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();
    expect(controller().animation!.value, greaterThan(0));
    expect(controller().animation!.value, lessThan(1));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.up();
    await drain();
    await swipe(-220);
    expect(selected(), 1);
    await swipe(-220);
    expect(selected(), 2);
    expect(find.byKey(const ValueKey('market-tab-owned')), findsNothing);
    expect(controller().length, 3);
    final count = api.requests.length;
    await swipe(-220);
    expect(api.requests.length, count);
    await swipe(220);
    expect(selected(), 1);
    await tester.tap(find.byKey(const ValueKey('market-tab-all')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await drain();
    expect(selected(), 0);
    final firstCount = api.requests.length;
    await swipe(220);
    expect(api.requests.length, firstCount);
    await tester.drag(area, const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await drain();
    expect(selected(), 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failed catalogue shows retry without invented templates', (
    tester,
  ) async {
    api.failing = 'GetTemplates';
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: TemplateMarketView(store: store, onUseTemplate: (_, _) {}),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('模板加载失败'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.byType(SliverGrid), findsNothing);
  });
  testWidgets('Cancelling paid confirmation never sends an order', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: TemplateMarketDetail(
            market: market,
            template: {'id': 7, 'name': '商务设计', 'price_points': 80},
            onUseTemplate: (_, _) {},
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await settlePreview(tester);
    expect(find.text('会员专享'), findsWidgets);
    expect(find.text('开通会员使用'), findsOneWidget);
    expect(api.calls, isNot(contains('PostTemplatesIdAcquisitions')));
  });
  test(
    'New resume using an acquired template retains its real template ID',
    () async {
      await store.updateResume(
        ResumeDraft(
          id: 0,
          title: '我的简历',
          marketTemplateID: 7,
          source: {'app_layout': 'market', 'app_template_name': '商务设计'},
        ),
      );
      final create = api.requests.firstWhere((r) => r.method == 'PostResumes');
      expect(create.body!['template_id'], 7);
      expect(store.resumes.single.marketTemplateID, 7);
    },
  );
  for (final dark in [false, true]) {
    testWidgets('Template preview has no fullscreen buttons ($dark)', (
      tester,
    ) async {
      tester.view.physicalSize = dark
          ? const Size(320, 640)
          : const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      api.documents['GetTemplatesId']!.addAll({
        'name': '简洁清晰的个人简历模板，适用于不同工作阶段',
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? appDarkTheme : appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(dark ? 1.6 : 1)),
              child: child!,
            ),
            home: TemplateMarketDetail(
              market: market,
              template: {'id': 7},
              onUseTemplate: (_, _) {},
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await settlePreview(tester);
      expect(find.byType(MarketTemplateArtwork), findsNothing);
      expect(find.byType(TemplateLivePreview), findsOneWidget);
      final stage = find.byKey(const ValueKey('template-preview-stage'));
      final author = find.byKey(const ValueKey('template-publisher-avatar'));
      expect(
        tester.getBottomLeft(author).dy,
        lessThan(tester.getTopLeft(stage).dy),
      );
      expect(
        find.ancestor(
          of: find.byType(TemplateLivePreview),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(tester.getSize(stage).height, greaterThan(100));
      expect(find.text('开通会员使用'), findsOneWidget);
      expect(api.calls, isNot(contains('GetTemplatesIdPreviewAssets')));
      expect(tester.takeException(), isNull);
      final web = preview.controllers.single;
      web.message(
        '{"type":"page-actions","items":[{"index":0,"top":0,"bottom":1}]}',
      );
      await tester.pumpAndSettle();
      expect(find.text('全屏查看'), findsNothing);
      expect(find.byTooltip('全屏查看第 1 页'), findsNothing);
      expect(find.byKey(const ValueKey('preview-page-action-0')), findsNothing);
      expect(
        tester
            .widget<TemplateLivePreview>(find.byType(TemplateLivePreview))
            .onOpenPage,
        isNull,
      );
      expect(preview.controllers, hasLength(1));
      expect(web.loadCount, 1);
      expect(
        api.requests.where((r) => r.method == 'GetTemplatesIdDom'),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
