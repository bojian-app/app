import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Login offers alternatives and requires explicit consent for WeChat',
    (tester) async {
      final authorizer = FakeWeChatAuthorizer();
      final api = FakeGateway();
      final store = await testStore(api: api, weChatAuthorizer: authorizer);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('auth-phone-login')), findsNothing);
      expect(find.byKey(const ValueKey('auth-douyin')), findsOneWidget);
      for (final key in [
        'auth-phone',
        'auth-code',
        'auth-submit',
        'auth-request-code',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('auth-wechat')));
      await tester.pumpAndSettle();
      expect(authorizer.calls, 0);
      expect(api.calls, isNot(contains('SendSMS')));
      await tester.tap(find.text('暂不同意'));
      await tester.pumpAndSettle();
      expect(authorizer.calls, 0);
      expect(store.isAuthenticated, isFalse);
    },
  );

  testWidgets('Douyin login requires explicit consent before authorization', (
    tester,
  ) async {
    final api = FakeGateway();
    final authorizer = FakeDouyinAuthorizer();
    final store = await testStore(api: api, douyinAuthorizer: authorizer);
    await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
    await tester.pumpAndSettle();
    final before = List<String>.of(api.calls);
    await tester.tap(find.byKey(const ValueKey('auth-douyin')));
    await tester.pumpAndSettle();
    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(api.calls, before);
    expect(authorizer.calls, 0);
    expect(store.isAuthenticated, isFalse);
    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('auth-wechat')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth-phone-login')), findsNothing);
    expect(api.calls, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Failed WeChat login can retry without creating a false session',
    (tester) async {
      final authorizer = FakeWeChatAuthorizer();
      final api = FakeGateway()..failing = 'WeChatLogin';
      final store = await testStore(api: api, weChatAuthorizer: authorizer);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-consent')));
      await tester.tap(find.byKey(const ValueKey('auth-wechat')));
      await tester.pumpAndSettle();
      expect(find.text('微信登录失败，请稍后重试'), findsOneWidget);
      expect(store.isAuthenticated, isFalse);
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('auth-wechat')));
      await tester.pumpAndSettle();
      expect(store.isAuthenticated, isTrue);
      expect(find.byType(AppShell), findsOneWidget);
      expect(authorizer.calls, 2);
      expect(api.calls, isNot(contains('SendSMS')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 400), const Size(844, 360)]) {
    testWidgets('Login options fit $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MyApp(startupAdsEnabled: false, store: await testStore()),
      );
      await tester.pumpAndSettle();
      for (final key in ['auth-wechat', 'auth-douyin', 'auth-consent']) {
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
