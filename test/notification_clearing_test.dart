import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Map<String, dynamic> _notice(int id, String title, {bool read = false}) => {
  'id': id,
  // Opens an article, so listing it does not mark it read.
  'type': 'ARTICLE_LIKE',
  'subject_type': 'ARTICLE',
  'subject_id': 8,
  'payload': {'title': title, 'body': '$title正文'},
  'read_at': read ? '2026-11-13T08:00:00Z' : null,
  'created_at': '2026-11-13T08:00:00Z',
};

Future<AppStore> _pump(WidgetTester tester, FakeGateway api) async {
  api.documents['GetNotifications'] = {
    'unread_count': 1,
    'items': [_notice(2, '第二条通知'), _notice(1, '第一条通知', read: true)],
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
  testWidgets('Swiping reveals delete for a notification', (tester) async {
    final api = FakeGateway();
    final store = await _pump(tester, api);
    await tester.drag(find.text('第二条通知'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('DeleteNotificationsId')));
    await tester.tap(find.byKey(const ValueKey('notification-delete-2')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DeleteNotificationsId'));
    expect(find.text('第二条通知'), findsNothing);
    expect(store.inbox.map((item) => item.id), [1]);
    expect(store.notificationUnreadCount, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Swiping marks an unread notification read', (tester) async {
    final api = FakeGateway();
    final store = await _pump(tester, api);
    // Read notifications only offer delete.
    await tester.drag(find.text('第一条通知'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-read-1')), findsNothing);
    await tester.drag(find.text('第二条通知'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-read-2')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostNotificationsRead'));
    expect(store.inbox.first.read, isTrue);
    expect(store.notificationUnreadCount, 0);
    expect(find.text('第二条通知'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Failed delete keeps the notification', (tester) async {
    final api = FakeGateway()..failing = 'DeleteNotificationsId';
    final store = await _pump(tester, api);
    await tester.drag(find.text('第二条通知'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-delete-2')));
    await tester.pumpAndSettle();
    expect(find.text('第二条通知'), findsOneWidget);
    expect(store.inbox, hasLength(2));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Clear all asks first and empties the inbox', (tester) async {
    final api = FakeGateway();
    final store = await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('notifications-clear-all')));
    await tester.pumpAndSettle();
    expect(find.text('清空全部通知？'), findsOneWidget);
    expect(api.calls, isNot(contains('PostNotificationsClear')));
    await tester.tap(find.byKey(const ValueKey('notifications-clear-confirm')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('PostNotificationsClear'));
    expect(store.inbox, isEmpty);
    expect(store.notificationUnreadCount, 0);
    expect(find.text('第一条通知'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
