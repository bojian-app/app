import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  testWidgets('Login validates consent and does not accept a local demo code', (
    tester,
  ) async {
    final api = FakeGateway()..rejectLogin = true;
    final store = await testStore(api: api);
    await tester.pumpWidget(MyApp(nativeStartup: true, store: store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-phone')),
      '13812345678',
    );
    await tester.enterText(find.byKey(const ValueKey('auth-code')), '123456');
    final submit = find.byKey(const ValueKey('auth-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('auth-consent')));
    await tester.tap(find.byKey(const ValueKey('auth-consent')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('验证码不正确'), findsOneWidget);
    expect(store.isAuthenticated, isFalse);
    api.rejectLogin = false;
    await tester.tap(submit);
    await tester.pump();
    await tester.pump();
    final fade = find
        .ancestor(
          of: find.byType(AppShell),
          matching: find.byType(FadeTransition),
        )
        .first;
    final start = tester.widget<FadeTransition>(fade).opacity.value;
    await tester.pump(const Duration(milliseconds: 140));
    final middle = tester.widget<FadeTransition>(fade).opacity.value;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(1));
    await tester.pumpAndSettle();
    expect(store.isAuthenticated, isTrue);
    expect(find.byKey(const ValueKey('nav-0')), findsOneWidget);
  });
  testWidgets('Verification action has space inside the field border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(nativeStartup: true, store: await testStore()),
    );
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(const ValueKey('auth-code')));
    final button = tester.getRect(
      find.byKey(const ValueKey('auth-request-code')),
    );
    expect(field.right - button.right, greaterThanOrEqualTo(12));
    expect(button.height, greaterThanOrEqualTo(40));
  });
  testWidgets(
    'Captcha consent is explicit, cancellable and continues automatically',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(api: api);
      await tester.pumpWidget(MyApp(nativeStartup: true, store: store));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone')),
        '13812345678',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      expect(find.text('用户协议与隐私政策'), findsOneWidget);
      expect(api.calls, isNot(contains('CreateCaptcha')));
      await tester.tap(find.text('暂不同意'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        isFalse,
      );
      await tester.tap(find.text('我已阅读并同意'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        isTrue,
      );
      await tester.tap(find.text('我已阅读并同意'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        isFalse,
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-agree-continue')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        isTrue,
      );
      expect(find.text('安全验证'), findsOneWidget);
      expect(api.calls.where((c) => c == 'CreateCaptcha'), hasLength(1));
      expect(api.calls, isNot(contains('SendSMS')));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('SendSMS')));
    },
  );
}
