import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_comment_tile.dart';
import 'package:bojian_mobile/content_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Long press offers report without replying; failed report preserves input',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      var replies = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ArticleCommentTile(
                comment: ArticleComment(
                  id: 37,
                  authorID: 900,
                  author: '用户',
                  content: '待举报评论',
                ),
                articleAuthorID: 900,
                currentUserID: store.userID,
                onReply: () => replies++,
                onReport: () => reportContent(
                  context,
                  store: store,
                  subjectType: 'COMMENT',
                  subjectID: 37,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('待举报评论'));
      await tester.pumpAndSettle();
      expect(replies, 0);
      expect(find.text('举报'), findsOneWidget);
      await tester.tap(find.text('举报'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('辱骂、骚扰或歧视'));
      await tester.enterText(find.byType(TextField), '包含人身攻击，请核查');
      await tester.pump();
      api.failing = 'PostReports';
      await tester.ensureVisible(find.text('提交举报'));
      await tester.tap(find.text('提交举报'));
      await tester.pumpAndSettle();
      expect(find.textContaining('服务器暂不可用'), findsOneWidget);
      expect(find.text('包含人身攻击，请核查'), findsOneWidget);
      expect(api.lastMutationBody?['subject_type'], 'COMMENT');
      expect(api.lastMutationBody?['subject_id'], 37);
      api.failing = null;
      await tester.tap(find.text('提交举报'));
      await tester.pumpAndSettle();
      expect(find.text('举报内容'), findsNothing);
      expect(find.text('举报已提交，我们会尽快核查'), findsOneWidget);
      expect(api.lastMutationBody?['reason_code'], 'ABUSE');
    },
  );

  testWidgets('Own and pending comments do not offer report', (tester) async {
    var reports = 0;
    for (final comment in [
      ArticleComment(id: 1, authorID: 2, author: '我', content: '测试评论'),
      ArticleComment(
        id: 1,
        authorID: 3,
        author: '用户',
        content: '测试评论',
        status: 'QUEUED',
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArticleCommentTile(
              comment: comment,
              articleAuthorID: 4,
              currentUserID: 2,
              onReport: () => reports++,
            ),
          ),
        ),
      );
      await tester.longPress(find.text('测试评论'));
      await tester.pumpAndSettle();
      expect(find.text('举报'), findsNothing);
    }
    expect(reports, 0);
  });
}
