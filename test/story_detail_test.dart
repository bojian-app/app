import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_rich_content.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Story story() => Story(
  id: 1,
  title: '文章本身的标题',
  author: '作者',
  role: '',
  category: '经验分享',
  excerpt: '',
  paragraphs: ['文章正文内容'],
  likes: 4,
);

void main() {
  testWidgets(
    'Reading page retains article title, omits toolbar copy and category, and sends comments',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      final article = story();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryDetail(story: article, store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(article.title), findsOneWidget);
      expect(find.text('正文'), findsNothing);
      expect(find.text('经验分享'), findsNothing);
      expect(find.text('文章正文内容'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '这份复盘很有用');
      await tester.pump();
      await tester.tap(find.byTooltip('发送评论'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('PostArticlesIdComments'));
      expect(article.comments.single.content, contains('这份复盘很有用'));
    },
  );

  testWidgets(
    'Detail fetches full formatted body rather than relying on a feed snapshot',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.documents['GetArticlesId'] = {
        'id': 1,
        'content': articleContentFromDelta([
          {
            'insert': '完整正文',
            'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
        ]),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: StoryDetail(story: story(), store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetArticlesId'));
      final body = tester.widget<Text>(find.text('完整正文'));
      expect(body.style!.fontSize, 19);
      expect(
        ((body.textSpan as TextSpan).children!.single as TextSpan)
            .style!
            .fontWeight,
        FontWeight.w700,
      );
    },
  );

  test(
    'Legacy active response toggles likes and never resets the existing count',
    () async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      final article = story();
      final feed = story();
      store.stories.add(feed);
      api.documents['PutArticlesIdLike'] = {'active': true};
      api.documents['DeleteArticlesIdLike'] = {'active': false};
      await store.like(article);
      expect(article.liked, isTrue);
      expect(article.likes, 5);
      expect(feed.likes, 5);
      await store.like(article);
      expect(article.liked, isFalse);
      expect(article.likes, 4);
      expect(api.calls, contains('DeleteArticlesIdLike'));
    },
  );

  test('Server count is authoritative and failures preserve state', () async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    final article = story();
    api.documents['PutArticlesIdLike'] = {'is_liked': true, 'like_count': 8};
    await store.like(article);
    expect(article.likes, 8);
    api.failing = 'DeleteArticlesIdLike';
    await expectLater(store.like(article), throwsA(anything));
    expect(article.liked, isTrue);
    expect(article.likes, 8);
  });
}
