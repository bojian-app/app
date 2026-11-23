import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_reaction_button.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DelayedReactionGateway extends FakeGateway {
  final response = Completer<ApiDocument>();
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'PutArticlesIdLike' || method == 'PutArticlesIdFavorite') {
      calls.add(method);
      return response.future;
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

Story article() => Story(
  id: 42,
  title: '测试',
  author: '作者',
  role: '',
  category: '动态',
  excerpt: '',
  paragraphs: [],
  likes: 3,
  favorites: 2,
);

void main() {
  testWidgets(
    'Feed card padding opens details and reaction taps stay in the feed',
    (tester) async {
      final api = DelayedReactionGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final story = article();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: ListView(
              children: [
                FeedRow(
                  child: StoryCard(flat: true, story: story, store: store),
                ),
              ],
            ),
          ),
        ),
      );
      final like = find.byKey(const ValueKey('story-like-42'));
      await tester.tap(like);
      await tester.pump();
      await tester.tap(like);
      await tester.pump();
      expect(find.byType(StoryDetail), findsNothing);
      expect(api.calls.where((m) => m == 'PutArticlesIdLike'), hasLength(1));
      api.response.complete(ApiDocument({'is_liked': true}));
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(StoryCard));
      await tester.tapAt(card.topRight + const Offset(-3, 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(StoryDetail), findsOneWidget);
      expect(api.calls, contains('GetArticlesId'));
      expect(api.calls, isNot(contains('GetArticlesIdComments')));
      await tester.pump(const Duration(milliseconds: 170));
      expect(
        api.calls.where((m) => m == 'GetArticlesIdComments'),
        hasLength(1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoryDetail), findsOneWidget);
    },
  );

  test(
    'Like is immediate, duplicate requests are ignored, server count wins',
    () async {
      final api = DelayedReactionGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final detail = article();
      final feed = article();
      store.stories.add(feed);
      final pending = store.like(detail);
      expect(detail.liked, true);
      expect(feed.likes, 4);
      await store.like(feed);
      expect(api.calls.where((m) => m == 'PutArticlesIdLike'), hasLength(1));
      api.response.complete(ApiDocument({'is_liked': true, 'like_count': 7}));
      await pending;
      expect(detail.likes, 7);
      expect(feed.likes, 7);
      expect(store.pending, isEmpty);
    },
  );

  test('Failed optimistic bookmark rolls back in detail and feed', () async {
    final api = DelayedReactionGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final detail = article();
    final feed = article();
    store.stories.add(feed);
    final pending = store.bookmark(detail);
    expect(detail.saved, true);
    expect(feed.saved, true);
    expect(detail.favorites, 3);
    expect(feed.favorites, 3);
    final failure = expectLater(pending, throwsA(isA<ApiFailure>()));
    api.response.completeError(const ApiFailure('网络错误'));
    await failure;
    expect(detail.saved, false);
    expect(feed.saved, false);
    expect(detail.favorites, 2);
    expect(feed.favorites, 2);
    expect(feed.likes, 3);
    expect(store.pending, isEmpty);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'Reaction feedback settles without spinners (reduced=$reduced)',
      (tester) async {
        var active = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return ArticleReactionButton(
                      reaction: ArticleReaction.like,
                      active: active,
                      count: active ? 4 : 3,
                      onTap: () => update(() => active = !active),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(ArticleReactionButton)).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(find.byType(ArticleReactionButton));
        await tester.pump();
        expect(find.byTooltip('取消点赞'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('4'), findsOneWidget);
        await tester.tap(find.byType(ArticleReactionButton));
        await tester.pumpAndSettle();
        expect(find.byTooltip('点赞'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
