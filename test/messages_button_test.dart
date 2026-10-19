import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_button.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Top message badges cap their text and announce the actual unread count',
    (tester) async {
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesButton(store: store)),
        ),
      );
      for (final unread in [0, 1, 99, 100, 12457]) {
        store.notificationUnreadCount = unread;
        store.changed();
        await tester.pumpAndSettle();
        final node = find.semantics.byLabel('消息').evaluate().single;
        expect(node, isSemantics(value: unread == 0 ? '' : '$unread条未读消息'));
        final badge = find.byKey(const ValueKey('messages-unread-badge'));
        if (unread == 0) {
          expect(badge, findsNothing);
        } else {
          expect(
            find.descendant(
              of: badge,
              matching: find.text(unread > 99 ? '99+' : '$unread'),
            ),
            findsOneWidget,
          );
        }
      }
      store.notificationUnreadCount = 1;
      store.conversations.add({'id': 1, 'unread_count': 2});
      store.changed();
      await tester.pumpAndSettle();
      expect(
        find.semantics.byLabel('消息').evaluate().single,
        isSemantics(value: '3条未读消息'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Repeated taps open one message page with a back path and both message categories',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: MessagesButton(store: store)),
        ),
      );
      api.calls.clear();
      final entry = find.byType(MessagesButton);
      await tester.tap(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      expect(find.text('消息'), findsOneWidget);
      expect(
        api.calls.where((call) => call == 'GetNotifications'),
        hasLength(1),
      );
      expect(
        api.calls.where((call) => call == 'GetConversations'),
        hasLength(1),
      );
      expect(find.text('暂无系统通知'), findsOneWidget);
      await tester.tap(find.text('聊天记录'));
      await tester.pumpAndSettle();
      expect(find.text('暂无聊天记录'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsNothing);
      expect(entry.hitTestable(), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
