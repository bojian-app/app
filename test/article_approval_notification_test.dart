import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/resume_guidance_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<AppStore> mount(
  WidgetTester tester,
  FakeGateway api,
  bool guidance,
) async {
  api.documents['GetNotifications'] = {
    'unread_count': 1,
    'items': [
      {
        'id': 20,
        'type': 'ARTICLE_APPROVED',
        'subject_type': 'ARTICLE',
        'subject_id': 8,
        'payload': {'body': '你的文章《求职复盘》已通过审核并发布。'},
      },
    ],
  };
  api.documents['GetArticlesId'] = {
    'id': 8,
    'title': '求职复盘',
    'author': {'id': 1, 'display_name': '测试账号'},
    'content': guidance
        ? {'kind': 'RESUME_GUIDANCE', 'question': '请帮我看看简历'}
        : richContent('文章正文'),
  };
  api.documents['GetArticlesIdGuidance'] = {
    'id': 8,
    'title': '求职复盘',
    'is_owner': true,
    'snapshot': {
      'personal_info': {'full_name': '测试账号'},
    },
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
  return store;
}

void main() {
  for (final guidance in [false, true]) {
    testWidgets(
      'Approval opens the right content and marks read (guidance=$guidance)',
      (tester) async {
        final api = FakeGateway();
        final store = await mount(tester, api, guidance);
        expect(find.text('文章审核通过'), findsOneWidget);
        expect(store.notificationUnreadCount, 1);
        expect(api.calls, isNot(contains('GetArticlesId')));
        await tester.tap(find.text('文章审核通过'));
        await tester.pumpAndSettle();
        expect(
          find.byType(guidance ? ResumeGuidanceView : StoryDetail),
          findsOneWidget,
        );
        expect(
          find.byType(guidance ? StoryDetail : ResumeGuidanceView),
          findsNothing,
        );
        expect(api.calls, contains('GetArticlesId'));
        if (guidance) expect(api.calls, contains('GetArticlesIdGuidance'));
        expect(api.calls, contains('PostNotificationsRead'));
        expect(store.inbox.single.read, isTrue);
        expect(store.notificationUnreadCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Failed approval content read stays unread (guidance=$guidance)',
      (tester) async {
        final api = FakeGateway()
          ..failing = guidance ? 'GetArticlesIdGuidance' : 'GetArticlesId';
        final store = await mount(tester, api, guidance);
        await tester.tap(find.text('文章审核通过'));
        await tester.pumpAndSettle();
        expect(find.byType(StoryDetail), findsNothing);
        expect(find.byType(ResumeGuidanceView), findsNothing);
        expect(store.inbox.single.read, isFalse);
        expect(store.notificationUnreadCount, 1);
        expect(api.calls, isNot(contains('PostNotificationsRead')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
