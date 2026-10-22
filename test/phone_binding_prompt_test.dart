import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/phone_binding_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> _login(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('auth-consent')));
  await tester.tap(find.byKey(const ValueKey('auth-wechat')));
  await tester.pumpAndSettle();
}

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

void main() {
  for (final bound in [false, true]) {
    testWidgets('WeChat login prompts only when phone bound=$bound', (
      tester,
    ) async {
      final api = FakeGateway();
      if (!bound) api.documents['GetMe']!.remove('phone_masked');
      final store = await testStore(
        api: api,
        weChatAuthorizer: FakeWeChatAuthorizer(),
      );
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      await _login(tester);
      expect(store.isAuthenticated, isTrue);
      expect(find.byType(AppShell), findsOneWidget);
      expect(
        find.byType(PhoneBindingDialog),
        bound ? findsNothing : findsOneWidget,
      );
      if (bound) return;
      await tester.tap(find.byKey(const ValueKey('phone-binding-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneBindingDialog), findsNothing);
      expect(store.isAuthenticated, isTrue);
      expect(api.calls, isNot(contains('PostMePhone')));
      await store.load('profile');
      await tester.pumpAndSettle();
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
      await tester.tap(find.byKey(const ValueKey('phone-binding-skip')));
      await store.endSession(remote: false);
      await tester.pumpAndSettle();
      await _login(tester);
      expect(find.byType(PhoneBindingDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Unknown profile does not appear unbound and can recover', (
    tester,
  ) async {
    final api = FakeGateway()..failing = 'GetMe';
    api.documents['GetMe']!.remove('phone_masked');
    final store = await testStore(
      api: api,
      weChatAuthorizer: FakeWeChatAuthorizer(),
    );
    await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
    await tester.pumpAndSettle();
    await _login(tester);
    expect(find.byType(PhoneBindingDialog), findsNothing);
    expect(store.phoneBindingChecked, isFalse);
    api.failing = null;
    await store.load('profile');
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBindingDialog), findsOneWidget);
  });

  testWidgets('Restored unbound session prompts once and Back skips safely', (
    tester,
  ) async {
    final api = FakeGateway();
    api.documents['GetMe']!.remove('phone_masked');
    final store = await testStore(authenticated: true, api: api);
    await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBindingDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBindingDialog), findsNothing);
    expect(store.isAuthenticated, isTrue);
    expect(api.calls, isNot(contains('PostMePhone')));
  });

  for (final size in [const Size(320, 600), const Size(844, 360)]) {
    testWidgets('Binding remains usable with keyboard and 2x text on $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FakeGateway();
      api.documents['GetMe']!.remove('phone_masked');
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      final phone = find.byKey(const ValueKey('phone-binding-phone'));
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '13800138000');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height > 400 ? 250 : 140,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final skip = find.byKey(const ValueKey('phone-binding-skip'));
      await tester.ensureVisible(skip);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(skip).bottom,
        lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(skip);
      await tester.pumpAndSettle();
      expect(find.byType(PhoneBindingDialog), findsNothing);
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
