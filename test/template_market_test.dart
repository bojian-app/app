import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/template_market.dart';
import 'package:bojian_mobile/template_market_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

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
  bool failOrderOnce = false;
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
    if (method == 'PostTemplateOrders') {
      calls.add(method);
      if (failOrderOnce) {
        failOrderOnce = false;
        throw const ApiFailure('连接中断');
      }
      documents['GetMeTemplates'] = {
        'items': [
          {'id': 7, 'name': '商务设计', 'source': 'ACQUIRED'},
        ],
      };
      documents['GetWallet'] = {'available_points': 120};
      return ApiDocument({
        'status': 'PAID',
        'wallet': {'available_points': 120},
      });
    }
    if (method == 'PostTemplatesIdAcquisitions') {
      calls.add(method);
      documents['GetMeTemplates'] = {
        'items': [
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
  setUp(() async {
    api = MarketGateway();
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
      'compatible': true,
      'status': 'PUBLISHED',
    };
    api.documents['GetWallet'] = {'available_points': 200};
  });
  tearDown(() {
    market.dispose();
    store.dispose();
  });
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
        {'id': 8, 'name': '自己的设计', 'source': 'PUBLISHED_BY_ME'},
      ],
    };
    await market.loadOwned();
    market.select(TemplateMarketFilter.owned);
    expect(market.visible.map((row) => row['id']), [7]);
    expect(market.authored, {8});
  });
  test('Paid confirmation binds quote and reuses idempotency key after a failed request', () async {
    api.failOrderOnce = true;
    await expectLater(
      market.acquire(
        id: 7,
        quotedPrice: 80,
        quotedRevision: 3,
        idempotencyKey: 'stable-key',
      ),
      throwsA(isA<ApiFailure>()),
    );
    await market.acquire(
      id: 7,
      quotedPrice: 80,
      quotedRevision: 3,
      idempotencyKey: 'stable-key',
    );
    final orders = api.requests
        .where((r) => r.method == 'PostTemplateOrders')
        .toList();
    expect(orders.length, 2);
    expect(orders.map((r) => r.headers['idempotency-key']), [
      'stable-key',
      'stable-key',
    ]);
    expect(orders.last.body!['expected_price_points'], 80);
    expect(orders.last.body!['expected_template_revision'], 3);
    expect(market.ownedIDs, {7});
    expect(store.points, 120);
    await market.acquire(
      id: 7,
      quotedPrice: 80,
      quotedRevision: 3,
      idempotencyKey: 'another-key',
    );
    expect(
      api.requests.where((r) => r.method == 'PostTemplateOrders').length,
      2,
    );
    expect(store.points, 120);
  });
  test(
    'Changed price and failed ownership check prevent any purchase request',
    () async {
      api.documents['GetTemplatesId']!['price_points'] = 90;
      await expectLater(
        market.acquire(
          id: 7,
          quotedPrice: 80,
          quotedRevision: 3,
          idempotencyKey: 'key',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, isNot(contains('PostTemplateOrders')));
      api.failing = 'GetMeTemplates';
      await expectLater(
        market.acquire(
          id: 7,
          quotedPrice: 90,
          quotedRevision: 3,
          idempotencyKey: 'key',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, isNot(contains('PostTemplateOrders')));
    },
  );
  test(
    'Free acquisition updates My templates without placing a paid order',
    () async {
      api.documents['GetTemplatesId']!.addAll({
        'price_points': 0,
        'pricing_type': 'FREE',
      });
      await market.acquire(
        id: 7,
        quotedPrice: 0,
        quotedRevision: 3,
        idempotencyKey: 'free-key',
      );
      expect(market.ownedIDs, {7});
      expect(api.calls, contains('PostTemplatesIdAcquisitions'));
      expect(api.calls, isNot(contains('PostTemplateOrders')));
    },
  );
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
        market.acquire(
          id: 7,
          quotedPrice: 80,
          quotedRevision: 3,
          idempotencyKey: 'key',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, isNot(contains('PostTemplateOrders')));
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
            'creator_name': '模板作者',
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
      expect(find.text('商务设计'), findsOneWidget);
      expect(find.text('80 积分'), findsOneWidget);
      expect(find.text('好设计，让重点自然被看见。'), findsNothing);
      expect(find.byType(SliverGrid), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('积分购买'));
    await tester.pumpAndSettle();
    expect(find.text('本次使用 80 积分'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostTemplateOrders')));
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
}
