import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_reaction_button.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/guidance_feed_card.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Map<String, dynamic> article(int id, {bool guidance = false}) => {
  'id': id,
  'title': guidance ? '前端开发工程师简历' : '我的求职经验 $id',
  'status': 'PUBLISHED',
  'author': {'id': 1, 'display_name': '测试账号'},
  'published_at': '2026-10-18T08:00:00Z',
  'content': guidance
      ? {'kind': 'RESUME_GUIDANCE', 'question': '想请大家帮我看看这份简历'}
      : richContent('整理项目经历时，也记录下自己的思考。'),
  'like_count': 3,
  'comment_count': 2,
  'is_liked': false,
  'is_favorited': false,
};

class ActivityGateway extends FakeGateway {
  List<Map<String, dynamic>> details = [article(1)];
  final requestedDetails = <int>[];
  final queries = <Map<String, String>>[];
  bool failDetail = false;
  bool holdDetails = false;
  final held = <int, Completer<ApiDocument>>{};

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'GetMeArticles') {
      calls.add(method);
      queries.add({...query});
      return ApiDocument({
        'items': [
          for (final detail in details)
            {
              'id': detail['id'],
              'title': detail['title'],
              'status': 'PUBLISHED',
            },
          {'id': 99, 'title': '未发布内容', 'status': 'DRAFT'},
        ],
      });
    }
    if (method == 'GetArticlesId') {
      calls.add(method);
      final id = int.parse(path['id']!);
      requestedDetails.add(id);
      if (failDetail) throw const ApiFailure('内容暂时无法加载');
      if (holdDetails) {
        return (held[id] = Completer<ApiDocument>()).future;
      }
      return ApiDocument(details.firstWhere((row) => row['id'] == id));
    }
    if (method == 'PutArticlesIdLike') {
      calls.add(method);
      return ApiDocument({'is_liked': true, 'like_count': 7});
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

Future<AppStore> mount(
  WidgetTester tester,
  ActivityGateway api, {
  bool dark = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme : appTheme,
      home: Scaffold(
        body: MyArticlesPage(store: store, embedded: true, publishedOnly: true),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return store;
}

void main() {
  for (final dark in [false, true]) {
    for (final guidance in [false, true]) {
      testWidgets(
        'Activity uses smaller text while preserving discovery alignment (guidance=$guidance, dark=$dark)',
        (tester) async {
          final row = article(1, guidance: guidance);
          final api = ActivityGateway()..details = [row];
          final store = await mount(tester, api, dark: dark);
          final card = find.byType(StoryCard);
          expect(card, findsOneWidget);
          expect(tester.widget<StoryCard>(card).flat, isTrue);
          expect(find.text('未发布内容'), findsNothing);
          expect(find.text('已发布'), findsNothing);
          expect(find.textContaining('发布时间：'), findsNothing);
          expect(api.requestedDetails, [1]);
          expect(api.queries.single, {'status': 'PUBLISHED', 'limit': '20'});
          expect(api.calls, isNot(contains('GetArticlesIdComments')));
          final title = find.text(
            guidance ? '想请大家帮我看看这份简历' : row['title'] as String,
          );
          final avatar = find.byKey(const ValueKey('story-author-avatar-1'));
          final cardSize = tester.getSize(card);
          final cardOrigin = tester.getTopLeft(card);
          final titleSize = tester.widget<Text>(title).style!.fontSize!;
          expect(titleSize, 14);
          final avatarRect = tester.getRect(avatar).shift(-cardOrigin);
          if (guidance) {
            expect(find.byType(GuidanceFeedCard), findsOneWidget);
            expect(find.text('想请大家帮我看看这份简历'), findsOneWidget);
          } else {
            expect(find.text('整理项目经历时，也记录下自己的思考。'), findsOneWidget);
            expect(find.byType(ArticleReactionButton), findsNWidgets(2));
          }
          // Compare the actual discovery page with the same real content.
          store.stories
            ..clear()
            ..add(decodeStory(row));
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? appDarkTheme : appTheme,
              home: Scaffold(body: DiscoveryPage(store: store)),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.getSize(card).width, cardSize.width);
          expect(tester.getSize(card).height, greaterThan(cardSize.height));
          final discoveryOrigin = tester.getTopLeft(card);
          expect(
            tester.widget<Text>(title).style!.fontSize,
            greaterThan(titleSize),
          );
          expect(tester.getRect(avatar).shift(-discoveryOrigin), avatarRect);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Activity reactions retain server results and open the real detail',
    (tester) async {
      final api = ActivityGateway();
      final store = await mount(tester, api);
      final feed = decodeStory(article(1));
      store.stories.add(feed);
      await tester.tap(find.byKey(const ValueKey('story-like-1')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消点赞'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(feed.likes, 7);
      store.changed();
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('story-bookmark-1')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消收藏'), findsOneWidget);
      expect(feed.saved, isTrue);
      await tester.tap(find.text('我的求职经验 1'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryDetail), findsOneWidget);
      expect(api.calls, contains('GetArticlesIdComments'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Guidance activity opens the existing guidance view', (
    tester,
  ) async {
    final api = ActivityGateway()..details = [article(1, guidance: true)];
    await mount(tester, api);
    await tester.tap(find.text('查看简历并指点'));
    await tester.pumpAndSettle();
    expect(find.byType(ResumeGuidanceView), findsOneWidget);
    expect(api.calls, contains('GetArticlesIdGuidance'));
    expect(api.calls, isNot(contains('GetArticlesIdComments')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed content loading can retry without showing a wrong card', (
    tester,
  ) async {
    final api = ActivityGateway()..failDetail = true;
    await mount(tester, api);
    expect(find.text('内容暂时无法加载'), findsOneWidget);
    expect(find.byType(StoryCard), findsNothing);
    api.failDetail = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryCard), findsOneWidget);
    expect(api.requestedDetails, [1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Content reads are bounded and stop after the page is disposed', (
    tester,
  ) async {
    final api = ActivityGateway()
      ..details = [for (var id = 1; id <= 9; id++) article(id)]
      ..holdDetails = true;
    await mount(tester, api, settle: false);
    await tester.pump();
    expect(api.requestedDetails, [1, 2, 3, 4]);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final entry in api.held.entries) {
      entry.value.complete(ApiDocument(article(entry.key)));
    }
    await tester.pumpAndSettle();
    expect(api.requestedDetails, [1, 2, 3, 4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'All content batches load and newly withdrawn articles stay hidden',
    (tester) async {
      final api = ActivityGateway()
        ..details = [
          for (var id = 1; id <= 9; id++)
            {...article(id), if (id == 9) 'status': 'DRAFT'},
        ];
      await mount(tester, api);
      expect(api.requestedDetails, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      await tester.scrollUntilVisible(find.text('我的求职经验 8'), 300);
      await tester.pumpAndSettle();
      expect(find.text('我的求职经验 8'), findsOneWidget);
      expect(find.text('我的求职经验 9'), findsNothing);
      expect(api.calls, isNot(contains('GetArticlesIdComments')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An expired session cannot load another batch or display old data',
    (tester) async {
      final api = ActivityGateway()
        ..details = [for (var id = 1; id <= 9; id++) article(id)]
        ..holdDetails = true;
      final store = await mount(tester, api, settle: false);
      await tester.pump();
      expect(api.requestedDetails, [1, 2, 3, 4]);
      await store.endSession(remote: false);
      for (final entry in api.held.entries) {
        entry.value.complete(ApiDocument(article(entry.key)));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.requestedDetails, [1, 2, 3, 4]);
      expect(find.byType(StoryCard), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
