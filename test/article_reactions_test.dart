import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_reaction_button.dart';
import 'package:bojian_mobile/design.dart';
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
  category: '经验分享',
  excerpt: '',
  paragraphs: [],
  likes: 3,
);

void main() {
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
    final failure = expectLater(pending, throwsA(isA<ApiFailure>()));
    api.response.completeError(const ApiFailure('网络错误'));
    await failure;
    expect(detail.saved, false);
    expect(feed.saved, false);
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
