import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Received article comment appears unread and opens the commented article',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetNotifications'] = {
        'unread_count': 1,
        'items': [
          {
            'id': 20,
            'type': 'ARTICLE_COMMENT',
            'subject_type': 'ARTICLE',
            'subject_id': 8,
            'payload': {'body': '小林评论了你的文章《面试复盘》：有帮助'},
            'read_at': null,
            'created_at': '2026-10-09T08:00:00Z',
          },
        ],
      };
      api.documents['GetArticlesId'] = {
        'id': 8,
        'title': '面试复盘',
        'author': {'id': 1, 'display_name': '我'},
        'content': richContent('文章正文'),
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      expect(store.inbox.single.subjectID, 8);
      expect(store.notificationUnreadCount, 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('收到新的评论'), findsOneWidget);
      expect(find.text('小林评论了你的文章《面试复盘》：有帮助'), findsOneWidget);
      await tester.tap(find.text('收到新的评论'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryDetail), findsOneWidget);
      expect(find.text('面试复盘'), findsOneWidget);
      expect(store.inbox.single.read, isTrue);
      expect(api.calls, contains('PostNotificationsRead'));
      expect(store.notificationUnreadCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed article access preserves the unread notification', (
    tester,
  ) async {
    final api = FakeGateway()..failing = 'GetArticlesId';
    api.documents['GetNotifications'] = {
      'unread_count': 1,
      'items': [
        {
          'id': 20,
          'type': 'ARTICLE_COMMENT',
          'subject_type': 'ARTICLE',
          'subject_id': 8,
          'payload': {'title': '收到新的评论', 'body': '小林赞了你的文章'},
          'read_at': null,
        },
      ],
    };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: MessagesPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('收到新的评论'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryDetail), findsNothing);
    expect(store.inbox.single.read, isFalse);
    expect(api.calls, isNot(contains('PostNotificationsRead')));
  });
}
