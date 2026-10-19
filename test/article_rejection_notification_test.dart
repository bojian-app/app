import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:bojian_mobile/my_articles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const reason = '请补充具体项目成果';

Future<AppStore> mount(
  WidgetTester tester,
  FakeGateway api, {
  bool guidance = false,
  String status = 'REJECTED',
  String reviewReason = reason,
  bool large = false,
}) async {
  tester.view.physicalSize = large
      ? const Size(320, 640)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  api.documents['GetNotifications'] = {
    'unread_count': 1,
    'items': [
      {
        'id': 20,
        'type': 'ARTICLE_REJECTED',
        'subject_type': 'ARTICLE',
        'subject_id': 8,
        'payload': {
          'review_reason': reviewReason,
          'body': '《求职复盘》未通过审核。审核意见：$reviewReason',
        },
      },
    ],
  };
  api.documents['GetArticlesId'] = {
    'id': 8,
    'title': '求职复盘',
    'status': status,
    'content': guidance
        ? {'kind': 'RESUME_GUIDANCE', 'question': '请帮我看看这份简历'}
        : richContent('文章正文'),
  };
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: large ? appDarkTheme : appTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
        child: child!,
      ),
      home: Scaffold(body: MessagesPage(store: store)),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  for (final guidance in [false, true]) {
    testWidgets(
      'Rejection opens own review result with its reason (guidance=$guidance)',
      (tester) async {
        final api = FakeGateway();
        final store = await mount(tester, api, guidance: guidance);
        expect(find.text('文章审核未通过'), findsOneWidget);
        expect(store.inbox.single.reviewReason, reason);
        await tester.tap(find.text('文章审核未通过'));
        await tester.pumpAndSettle();
        expect(find.byType(OwnArticlePreview), findsOneWidget);
        expect(find.text('未通过'), findsOneWidget);
        expect(find.text('审核意见：$reason'), findsOneWidget);
        expect(find.text(guidance ? '请帮我看看这份简历' : '文章正文'), findsOneWidget);
        expect(api.calls, isNot(contains('GetArticlesIdGuidance')));
        expect(api.calls, isNot(contains('GetArticlesIdComments')));
        expect(store.inbox.single.read, isTrue);
        expect(store.notificationUnreadCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Failed rejection content read preserves unread', (tester) async {
    final api = FakeGateway()..failing = 'GetArticlesId';
    final store = await mount(tester, api);
    await tester.tap(find.text('文章审核未通过'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnArticlePreview), findsNothing);
    expect(store.inbox.single.read, isFalse);
    expect(store.notificationUnreadCount, 1);
    expect(api.calls, isNot(contains('PostNotificationsRead')));
  });
  testWidgets(
    'A rejected article returned to drafts retains the review reason',
    (tester) async {
      await mount(tester, FakeGateway(), status: 'DRAFT');
      await tester.tap(find.text('文章审核未通过'));
      await tester.pumpAndSettle();
      expect(find.byType(OwnArticlePreview), findsOneWidget);
      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('审核意见：$reason'), findsOneWidget);
      expect(find.text('文章正文'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final entry in [('SUBMITTED', '审核中'), ('PUBLISHED', '已发布')]) {
    testWidgets('Historical rejection retains current ${entry.$1} status', (
      tester,
    ) async {
      await mount(tester, FakeGateway(), status: entry.$1);
      await tester.tap(find.text('文章审核未通过'));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text('未通过'), findsNothing);
      expect(find.text('上次审核意见：$reason'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Long rejection reason remains scrollable with large text', (
    tester,
  ) async {
    await mount(
      tester,
      FakeGateway(),
      reviewReason: '请补充实际项目成果。' * 20,
      large: true,
    );
    await tester.tap(find.text('文章审核未通过'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnArticlePreview), findsOneWidget);
    await tester.scrollUntilVisible(find.text('文章正文'), 300);
    await tester.pumpAndSettle();
    expect(find.text('文章正文').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
