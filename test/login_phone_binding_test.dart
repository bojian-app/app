import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/login_phone_binding_page.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/phone_binding_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _DelayedGateway extends FakeGateway {
  Completer<ApiDocument>? profile;
  Completer<ApiDocument>? binding;

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'GetMe' && profile != null) return profile!.future;
    if (method == 'PostMePhone' && binding != null) {
      calls.add(method);
      return binding!.future;
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

Future<void> _startWeChatLogin(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('auth-consent')));
  await tester.tap(find.byKey(const ValueKey('auth-wechat')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('WeChat login waits for the phone step before any session', (
    tester,
  ) async {
    final api = FakeGateway()..requirePhoneBinding = true;
    final store = await testStore(
      api: api,
      weChatAuthorizer: FakeWeChatAuthorizer(),
    );
    await tester.pumpWidget(
      MyApp(
        startupAnimationEnabled: false,
        bannerAdsEnabled: false,
        store: store,
      ),
    );
    await tester.pumpAndSettle();
    await _startWeChatLogin(tester);
    expect(find.byType(LoginPhoneBindingPage), findsOneWidget);
    expect(store.isAuthenticated, isFalse);
    expect(await store.storage.read('bojian.session'), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPhoneBindingPage), findsNothing);
    expect(store.isAuthenticated, isFalse);
    expect(find.byKey(const ValueKey('auth-error')), findsNothing);
    expect(api.calls, isNot(contains('ConfirmLoginPhoneBinding')));

    await tester.tap(find.byKey(const ValueKey('auth-wechat')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-phone-binding-code')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('login-phone-binding-submit')));
    await tester.pumpAndSettle();
    expect(find.text('请先获取当前手机号的验证码'), findsOneWidget);
    expect(store.isAuthenticated, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('Proved phone completes a pending third-party login', () async {
    final api = FakeGateway()..requirePhoneBinding = true;
    final store = await testStore(
      api: api,
      douyinAuthorizer: FakeDouyinAuthorizer(),
    );
    addTearDown(store.dispose);
    String? boundToken;
    final signedIn = await store.signInWithDouyin(
      bindPhone: (token) async {
        boundToken = token;
        return (
          response: await store.confirmLoginPhoneBinding(
            token,
            '13700137000',
            '123456',
          ),
          phone: '13700137000',
        );
      },
    );
    expect(signedIn, isTrue);
    expect(boundToken, 'phone-binding-token');
    expect(store.isAuthenticated, isTrue);
    expect(store.hasBoundPhone, isTrue);
    expect(store.phoneMasked, '137****7000');
  });

  test('Third-party login without a phone step never signs in', () async {
    final api = FakeGateway()..requirePhoneBinding = true;
    final store = await testStore(
      api: api,
      weChatAuthorizer: FakeWeChatAuthorizer(),
    );
    addTearDown(store.dispose);
    await expectLater(store.signInWithWeChat(), throwsA(isA<ApiFailure>()));
    expect(store.isAuthenticated, isFalse);
    expect(await store.signInWithWeChat(bindPhone: (_) async => null), isFalse);
    expect(store.isAuthenticated, isFalse);
    expect(await store.storage.read('bojian.session'), isNull);
  });

  testWidgets('An unbound account is not interrupted after sign in', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetMe']!.remove('phone_masked');
    final store = await testStore(authenticated: true, api: api);
    await tester.pumpWidget(
      MyApp(
        startupAnimationEnabled: false,
        bannerAdsEnabled: false,
        store: store,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(PhoneBindingDialog), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-menu')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('隐私与设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐私与设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('账号安全'));
    await tester.pumpAndSettle();
    final phoneRow = find.byKey(const ValueKey('security-phone-binding'));
    await tester.ensureVisible(phoneRow);
    await tester.tap(phoneRow);
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBindingDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 600), const Size(844, 360)]) {
    testWidgets('Login phone step stays usable with 2x text on $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FakeGateway()..requirePhoneBinding = true;
      final store = await testStore(
        api: api,
        weChatAuthorizer: FakeWeChatAuthorizer(),
      );
      await tester.pumpWidget(
        MyApp(
          startupAnimationEnabled: false,
          bannerAdsEnabled: false,
          store: store,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth-consent')));
      await tester.tap(find.byKey(const ValueKey('auth-consent')));
      await tester.ensureVisible(find.byKey(const ValueKey('auth-wechat')));
      await tester.tap(find.byKey(const ValueKey('auth-wechat')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-phone-binding-phone')),
        '13800138000',
      );
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height > 400 ? 250 : 140,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('login-phone-binding-submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(submit).bottom,
        lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('Late binding response cannot update a signed out account', () async {
    final api = _DelayedGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.binding = Completer<ApiDocument>();
    final result = store.bindPhone('13800138000', '123456');
    await Future<void>.delayed(Duration.zero);
    await store.endSession(remote: false);
    api.binding!.complete(ApiDocument({'phone_masked': '138****8000'}));
    await expectLater(result, throwsA(isA<ApiFailure>()));
    expect(store.phoneMasked, isEmpty);
    expect(store.phoneBindingChecked, isFalse);
    expect(store.isAuthenticated, isFalse);
  });

  test('An older profile response cannot undo a successful binding', () async {
    final api = _DelayedGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    api.profile = Completer<ApiDocument>();
    final loading = store.load('profile');
    await Future<void>.delayed(Duration.zero);
    await store.bindPhone('13800138000', '123456');
    api.profile!.complete(
      ApiDocument({'nickname': '测试账号', 'profile_visibility': 'PUBLIC'}),
    );
    await loading;
    expect(store.phoneMasked, '138****8000');
    expect(store.hasBoundPhone, isTrue);
  });
}
