import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class SavedGateway extends FakeGateway {
  bool saved = true;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMeFavorites') {
      calls.add(method);
      if (failing == method) throw const ApiFailure('服务器暂不可用');
      return ApiDocument({
        'items': saved
            ? [
                {
                  'id': 1,
                  'title': '前端面试经验与复盘',
                  'collected_at': '2026-10-08T09:20:16Z',
                },
              ]
            : [],
      });
    }
    if (method == 'GetArticlesId') {
      calls.add(method);
      return ApiDocument({
        'id': 1,
        'title': '前端面试经验与复盘',
        'is_favorited': saved,
        'content': richContent('真实文章正文'),
        'author': {'id': 2, 'display_name': '文章作者'},
      });
    }
    if (method == 'DeleteArticlesIdFavorite' ||
        method == 'PutArticlesIdFavorite') {
      calls.add(method);
      if (failing == method) throw const ApiFailure('取消失败');
      saved = method == 'PutArticlesIdFavorite';
      return ApiDocument({});
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

Future<void> launch(
  WidgetTester tester,
  SavedGateway api, {
  Size size = const Size(360, 780),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = await testStore(authenticated: true, api: api);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: StorySearch(store: store, savedOnly: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Collection uses server summaries and fetches body only when opened',
    (tester) async {
      final api = SavedGateway();
      await launch(tester, api);
      expect(find.text('前端面试经验与复盘'), findsOneWidget);
      expect(api.calls.where((method) => method == 'GetArticlesId'), isEmpty);
      await tester.tap(find.text('前端面试经验与复盘'));
      await tester.pumpAndSettle();
      expect(find.text('真实文章正文'), findsOneWidget);
      await tester.tap(find.byTooltip('取消收藏'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('真实文章正文'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('还没有收藏的文章'), findsOneWidget);
      expect(api.saved, isFalse);
    },
  );

  testWidgets(
    'Removing and undoing a favorite persist both operations on the server',
    (tester) async {
      final api = SavedGateway();
      await launch(tester, api);
      await tester.tap(find.byKey(const ValueKey('saved-remove-1')));
      await tester.pumpAndSettle();
      expect(find.text('前端面试经验与复盘'), findsNothing);
      expect(api.saved, isFalse);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(find.text('前端面试经验与复盘'), findsOneWidget);
      expect(api.saved, isTrue);
      expect(
        api.calls,
        containsAll(['DeleteArticlesIdFavorite', 'PutArticlesIdFavorite']),
      );
    },
  );

  testWidgets('Failed cancellation retains the favorite', (tester) async {
    final api = SavedGateway()..failing = 'DeleteArticlesIdFavorite';
    await launch(tester, api);
    await tester.tap(find.byKey(const ValueKey('saved-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('前端面试经验与复盘'), findsOneWidget);
    expect(api.saved, isTrue);
    expect(find.text('取消失败'), findsOneWidget);
  });

  testWidgets('Search and long titles fit a small landscape screen', (
    tester,
  ) async {
    final api = SavedGateway();
    await launch(tester, api, size: const Size(780, 360));
    await tester.enterText(find.byKey(const ValueKey('saved-search')), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有找到这篇收藏'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text('前端面试经验与复盘'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Loading errors are retryable and do not masquerade as an empty collection',
    (tester) async {
      final api = SavedGateway()..failing = 'GetMeFavorites';
      await launch(tester, api);
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(find.text('还没有收藏的文章'), findsNothing);
      api.failing = null;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('前端面试经验与复盘'), findsOneWidget);
    },
  );
}
