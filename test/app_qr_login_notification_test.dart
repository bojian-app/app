import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Website login notification opens details and marks read, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const body =
            '你的博简账号已通过 App 扫码登录官网。\n登录设备：Windows · Chrome\n如非本人操作，请在「账号安全」中检查并移除该登录设备。';
        final api = FakeGateway();
        api.documents['GetNotifications'] = {
          'unread_count': 1,
          'items': [
            {
              'id': 55,
              'type': 'LOGIN_SUCCEEDED',
              'subject_type': 'USER_SESSION',
              'subject_id': 123,
              'payload': {'title': '官网登录成功', 'body': body},
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'read_at': null,
            },
          ],
        };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await store.load('messages');
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? appDarkTheme : appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(body: MessagesPage(store: store)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('官网登录成功'), findsOneWidget);
        expect(store.notificationUnreadCount, 1);
        await tester.tap(find.text('官网登录成功'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          body,
        );
        expect(store.notificationUnreadCount, 0);
        expect(store.inbox.single.read, isTrue);
        expect(
          api.calls.where((call) => call == 'PostNotificationsRead'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
