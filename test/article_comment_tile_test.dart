import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_comment_tile.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  test(
    'Comment loading retains identity, avatar, timestamp and server total',
    () async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      api.documents['GetArticlesIdComments'] = {
        'total': 6,
        'items': [
          {
            'id': 8,
            'content': '作者评论',
            'created_at': '2026-10-08T09:57:33Z',
            'author': {
              'id': 2,
              'display_name': '同名用户',
              'avatar_url': 'https://example.com/avatar.png',
            },
          },
        ],
      };
      final article = Story(
        id: 1,
        title: '',
        author: '同名用户',
        authorID: 2,
        role: '',
        category: '',
        excerpt: '',
        paragraphs: [],
      );
      await store.article(article);
      expect(article.commentCount, 6);
      expect(article.comments.single.authorID, 2);
      expect(
        article.comments.single.avatarURL,
        'https://example.com/avatar.png',
      );
      expect(
        article.comments.single.createdAt,
        DateTime.utc(2026, 10, 8, 9, 57, 33),
      );
    },
  );

  testWidgets('Author badge follows account IDs rather than matching names', (
    tester,
  ) async {
    const comments = [
      ArticleComment(id: 1, authorID: 2, author: '同名用户', content: '作者的评论'),
      ArticleComment(id: 2, authorID: 3, author: '同名用户', content: '普通用户评论'),
      ArticleComment(id: 3, authorID: 0, author: '同名用户', content: '缺少身份的评论'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Column(
            children: [
              for (final comment in comments)
                ArticleCommentTile(comment: comment, articleAuthorID: 2),
            ],
          ),
        ),
      ),
    );
    expect(find.text('作者'), findsOneWidget);
    expect(find.byKey(const ValueKey('comment-author-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('comment-author-2')), findsNothing);
    expect(find.byKey(const ValueKey('comment-author-3')), findsNothing);
  });

  testWidgets(
    'Deleted comments do not expose identity or receive author badges',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(
            body: ArticleCommentTile(
              comment: ArticleComment(
                id: 1,
                authorID: 2,
                author: '已删除用户昵称',
                content: '删除前内容',
                deleted: true,
              ),
              articleAuthorID: 2,
            ),
          ),
        ),
      );
      expect(find.text('该评论已删除'), findsOneWidget);
      expect(find.text('已删除用户昵称'), findsNothing);
      expect(find.text('删除前内容'), findsNothing);
      expect(find.text('作者'), findsNothing);
    },
  );

  testWidgets('Long names wrap together with author badges on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ArticleCommentTile(
                comment: ArticleComment(
                  id: 1,
                  authorID: 2,
                  author: '这是一个比较长的作者昵称用来检查换行情况',
                  content: '评论的正文内容。' * 8,
                  createdAt: DateTime.utc(2026, 10, 8, 9, 57, 33),
                ),
                articleAuthorID: 2,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('作者'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(780, 360);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
