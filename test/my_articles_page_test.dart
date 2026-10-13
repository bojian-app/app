import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ArticleGateway extends FakeGateway {
  final queries = <Map<String, String>>[];
  Completer<ApiDocument>? pending;
  bool fail = false;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMeArticles') {
      queries.add({...query});
      if (fail) throw const ApiFailure('服务器暂不可用');
      if (pending != null && query['status'] == 'SUBMITTED') {
        return pending!.future;
      }
      final status = query['status'];
      return ApiDocument(
        {
          'items': [
            {
              'id': query.containsKey('cursor') ? 2 : 1,
              'title': query.containsKey('cursor') ? '第二篇审核文章' : '$status 的文章',
              'status': status,
              'updated_at': '2026-10-08T09:20:16Z',
              'published_at': '2026-10-07T09:20:16Z',
              'review_reason': status == 'REJECTED' ? '请补充原创内容' : '',
              'like_count': 3,
            },
          ],
        },
        nextCursor: status == 'SUBMITTED' && !query.containsKey('cursor')
            ? 'page-2'
            : '',
      );
    }
    if (method == 'GetArticlesId') {
      calls.add(method);
      return ApiDocument({
        'id': 1,
        'title': '审核中的正文',
        'content': richContent('尚未公开的文章内容'),
      });
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
  ArticleGateway api, {
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
      home: StorySearch(store: store, mineOnly: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Own articles defaults to pending review and loads details only on tap',
    (tester) async {
      final api = ArticleGateway();
      await launch(tester, api);
      expect(find.byType(MyArticlesPage), findsOneWidget);
      expect(api.queries.single['status'], 'SUBMITTED');
      expect(find.text('SUBMITTED 的文章'), findsOneWidget);
      expect(api.calls, isNot(contains('GetArticlesId')));
      await tester.tap(find.text('SUBMITTED 的文章'));
      await tester.pumpAndSettle();
      expect(find.text('尚未公开的文章内容'), findsOneWidget);
      expect(find.text('审核中'), findsOneWidget);
      expect(api.calls, contains('GetArticlesId'));
      expect(api.calls, isNot(contains('GetArticlesIdComments')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('All status tabs send valid filters and show rejection reasons', (
    tester,
  ) async {
    final api = ArticleGateway();
    await launch(tester, api);
    for (final status in ['PUBLISHED', 'DRAFT', 'REJECTED']) {
      await tester.tap(find.byKey(ValueKey('articles-$status')));
      await tester.pumpAndSettle();
      expect(api.queries.last['status'], status);
      expect(find.text('$status 的文章'), findsOneWidget);
    }
    expect(find.text('审核意见：请补充原创内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pagination retains pending articles and carries status and cursor',
    (tester) async {
      final api = ArticleGateway();
      await launch(tester, api);
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(api.queries.last, containsPair('status', 'SUBMITTED'));
      expect(api.queries.last, containsPair('cursor', 'page-2'));
      expect(find.text('SUBMITTED 的文章'), findsOneWidget);
      expect(find.text('第二篇审核文章'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing);
    },
  );

  testWidgets(
    'A late pending response cannot replace the selected draft list',
    (tester) async {
      final api = ArticleGateway()..pending = Completer<ApiDocument>();
      tester.view.physicalSize = const Size(844, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: MyArticlesPage(store: store),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('articles-DRAFT')));
      await tester.pumpAndSettle();
      api.pending!.complete(
        ApiDocument({
          'items': [
            {'id': 99, 'title': '过期响应', 'status': 'SUBMITTED'},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('DRAFT 的文章'), findsOneWidget);
      expect(find.text('过期响应'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Connection errors can be retried without presenting an empty state',
    (tester) async {
      final api = ArticleGateway()..fail = true;
      await launch(tester, api);
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(find.text('暂无审核中的文章'), findsNothing);
      api.fail = false;
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(find.text('SUBMITTED 的文章'), findsOneWidget);
    },
  );
}
