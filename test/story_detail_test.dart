import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_reaction_button.dart';
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
  category: '动态',
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
      expect(
        tester
            .widget<ArticleReactionButton>(
              find.byKey(const ValueKey('detail-like')),
            )
            .count,
        article.likes,
      );
      expect(find.text(article.title), findsOneWidget);
      expect(find.text('正文'), findsNothing);
      expect(find.text('动态'), findsNothing);
      expect(find.text('文章正文内容'), findsOneWidget);
      final actions = find.byKey(const ValueKey('article-end-actions'));
      expect(
        find.descendant(
          of: actions,
          matching: find.byType(ArticleReactionButton),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(ArticleReactionButton),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(actions).dy,
        greaterThan(tester.getBottomLeft(find.byType(ArticleRichBody)).dy),
      );
      expect(
        tester.getBottomLeft(actions).dy,
        lessThan(tester.getTopLeft(find.text('评论（0）')).dy),
      );
      await tester.enterText(find.byType(TextField), '这份复盘很有用');
      await tester.pump();
      await tester.tap(find.byTooltip('发送评论'));
      await tester.pumpAndSettle();
      // Comments are queued for moderation instead of joining the story at once.
      expect(api.calls, contains('PostArticlesIdComments'));
      final queued = store.contentSubmissions.last;
      expect(queued['_scope_id'], article.id);
      expect(queued['content'], contains('这份复盘很有用'));
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

  testWidgets('Headings give the page a table of contents that jumps to them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic> block(String kind, String text) => {
      'kind': kind,
      'spans': [
        {'text': text},
      ],
    };
    final article = Story(
      id: 1,
      title: '长文',
      author: '作者',
      role: '',
      category: '动态',
      excerpt: '',
      paragraphs: const [],
      content: {
        'blocks': [
          block('heading2', '第一章'),
          for (var i = 0; i < 24; i++) block('paragraph', '第一章的内容，第 $i 段。' * 3),
          block('heading3', '第二章'),
          for (var i = 0; i < 24; i++) block('paragraph', '第二章的内容，第 $i 段。' * 3),
          block('heading2', '第三章'),
          block('paragraph', '结尾'),
        ],
      },
    );
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryDetail(story: article, store: store),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('article-contents-button'));
    expect(button, findsOneWidget);
    // The right-most action icon sits on the page gutter, not at the edge.
    expect(tester.getRect(button).right, lessThanOrEqualTo(360 - 10 + .5));
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, 0);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('目录'), findsOneWidget);
    for (final title in ['第一章', '第二章', '第三章']) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('article-contents')),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('article-contents')),
        matching: find.text('第二章'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('article-contents')), findsNothing);
    expect(scrollable.position.pixels, greaterThan(100));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('An article without headings has no contents button', (
    tester,
  ) async {
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: StoryDetail(story: story(), store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('article-contents-button')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
