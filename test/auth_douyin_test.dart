import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/api/generated/auth.pb.dart' as auth;
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/legal_document.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/phone_binding_dialog.dart';
import 'package:bojian_mobile/douyin_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _Authorizer implements DouyinAuthorizer {
  int calls = 0;
  final result = Completer<String?>();
  @override
  Future<String?> authorize() {
    calls++;
    return result.future;
  }
}

class _Gateway extends FakeGateway {
  ApiFailure? failure;
  bool invalidIdentity = false;
  Completer<auth.LoginResponse>? pendingExchange;
  final exchangeStarted = Completer<void>();
  @override
  Future<auth.LoginResponse> loginWithDouyin(
    String code,
    Map<String, String> agreements,
    Map<String, String> headers,
  ) async {
    expect(code, 'dy-code');
    expect(agreements, legalAgreementVersions);
    expect(headers['x-device-id'], isNotEmpty);
    if (pendingExchange != null) {
      calls.add('DouyinLogin');
      exchangeStarted.complete();
      return pendingExchange!.future;
    }
    if (failure != null) {
      calls.add('DouyinLogin');
      throw failure!;
    }
    if (invalidIdentity) {
      return auth.LoginResponse(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: auth.UserIdentity(),
      );
    }
    return super.loginWithDouyin(code, agreements, headers);
  }
}

void main() {
  testWidgets('Douyin login asks for consent before opening Douyin', (
    tester,
  ) async {
    final authorizer = _Authorizer();
    final store = await testStore(douyinAuthorizer: authorizer);
    await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('auth-douyin'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(authorizer.calls, 0);
    expect(store.isAuthenticated, isFalse);
    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(find.text('同意后将打开抖音，请在抖音中确认授权登录。'), findsNothing);
    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();
    expect(authorizer.calls, 0);
  });
  for (final result in ['success', 'cancel', 'failure']) {
    testWidgets('Douyin $result preserves the correct login state', (
      tester,
    ) async {
      final authorizer = _Authorizer();
      final gateway = _Gateway();
      if (result == 'failure') {
        gateway.failure = const ApiFailure('抖音授权失败，请重新登录');
      }
      if (result == 'success') {
        gateway.documents['GetMe']!.remove('phone_masked');
      }
      final store = await testStore(api: gateway, douyinAuthorizer: authorizer);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth-consent')));
      await tester.tap(find.byKey(const ValueKey('auth-consent')));
      final button = find.byKey(const ValueKey('auth-douyin'));
      await tester.ensureVisible(button);
      final initialButtonRect = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(authorizer.calls, 1);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('auth-wechat')))
            .onPressed,
        isNull,
      );
      authorizer.result.complete(result == 'cancel' ? null : 'dy-code');
      await tester.pumpAndSettle();
      expect(store.isAuthenticated, result == 'success');
      expect(
        gateway.calls.where((call) => call == 'DouyinLogin'),
        hasLength(result == 'cancel' ? 0 : 1),
      );
      if (result == 'success') {
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(PhoneBindingDialog), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('phone-binding-skip')));
        await tester.pumpAndSettle();
        expect(find.byType(PhoneBindingDialog), findsNothing);
        expect(store.isAuthenticated, isTrue);
        expect(gateway.calls, isNot(contains('PostMePhone')));
        expect(
          await store.storage.read('bojian.session'),
          contains('test-access'),
        );
      } else {
        expect(find.byType(SnackBar), findsNothing);
        if (result == 'cancel') {
          expect(find.text('已取消抖音登录'), findsNothing);
          expect(find.byKey(const ValueKey('auth-status')), findsNothing);
          expect(find.byKey(const ValueKey('auth-error')), findsNothing);
          expect(tester.getRect(button), initialButtonRect);
        } else {
          expect(find.text('抖音授权失败，请重新登录'), findsOneWidget);
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('auth-error'))).dy,
            greaterThan(tester.getBottomLeft(button).dy),
          );
        }
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        expect(find.byKey(const ValueKey('auth-douyin')), findsOneWidget);
        expect(find.byKey(const ValueKey('auth-submit')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('Late Douyin authorization cannot sign in after logout', () async {
    final authorizer = _Authorizer();
    final gateway = _Gateway();
    final store = await testStore(api: gateway, douyinAuthorizer: authorizer);
    addTearDown(store.dispose);
    final pending = store.signInWithDouyin();
    await Future<void>.delayed(Duration.zero);
    await store.endSession(remote: false);
    authorizer.result.complete('dy-code');
    await expectLater(pending, throwsA(isA<ApiFailure>()));
    expect(gateway.calls, isNot(contains('DouyinLogin')));
    expect(store.isAuthenticated, isFalse);
  });
  test(
    'Invalid server identity is rejected before saving a Douyin session',
    () async {
      final authorizer = _Authorizer()..result.complete('dy-code');
      final gateway = _Gateway()..invalidIdentity = true;
      final store = await testStore(api: gateway, douyinAuthorizer: authorizer);
      addTearDown(store.dispose);
      await expectLater(store.signInWithDouyin(), throwsA(isA<ApiFailure>()));
      expect(store.isAuthenticated, isFalse);
      expect(await store.storage.read('bojian.session'), isNull);
    },
  );

  test(
    'A late server exchange cannot restore the ended login session',
    () async {
      final authorizer = _Authorizer()..result.complete('dy-code');
      final gateway = _Gateway()
        ..pendingExchange = Completer<auth.LoginResponse>();
      final store = await testStore(api: gateway, douyinAuthorizer: authorizer);
      addTearDown(store.dispose);
      final pending = store.signInWithDouyin();
      await gateway.exchangeStarted.future;
      await store.endSession(remote: false);
      gateway.pendingExchange!.complete(await gateway.login('', '', {}));
      await expectLater(pending, throwsA(isA<ApiFailure>()));
      expect(store.isAuthenticated, isFalse);
      expect(await store.storage.read('bojian.session'), isNull);
    },
  );

  for (final size in [const Size(320, 400), const Size(844, 360)]) {
    testWidgets(
      'Pending Douyin authorization fits $size with large dark text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final authorizer = _Authorizer();
        final store = await testStore(douyinAuthorizer: authorizer);
        await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
        await tester.pumpAndSettle();
        final consent = find.byKey(const ValueKey('auth-consent'));
        await tester.ensureVisible(consent);
        await tester.tap(consent);
        final button = find.byKey(const ValueKey('auth-douyin'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(find.text('正在等待抖音授权…'), findsOneWidget);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(tester.takeException(), isNull);
        authorizer.result.complete(null);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        expect(store.isAuthenticated, isFalse);
      },
    );
  }
}
