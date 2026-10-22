import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/api/generated/auth.pb.dart' as auth;
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/legal_document.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/wechat_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _Authorizer implements WeChatAuthorizer {
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
  @override
  Future<auth.LoginResponse> loginWithWeChat(
    String code,
    Map<String, String> agreements,
    Map<String, String> headers,
  ) async {
    expect(code, 'wx-code');
    expect(agreements, legalAgreementVersions);
    expect(headers['x-device-id'], isNotEmpty);
    if (failure != null) {
      calls.add('WeChatLogin');
      throw failure!;
    }
    if (invalidIdentity) {
      return auth.LoginResponse(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: auth.UserIdentity(),
      );
    }
    return super.loginWithWeChat(code, agreements, headers);
  }
}

void main() {
  testWidgets('WeChat login asks for consent before opening WeChat', (
    tester,
  ) async {
    final authorizer = _Authorizer();
    final store = await testStore(weChatAuthorizer: authorizer);
    await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('auth-wechat'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(authorizer.calls, 0);
    expect(store.isAuthenticated, isFalse);
    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(find.text('同意后将打开微信，请在微信中确认授权登录。'), findsNothing);
    await tester.tap(find.text('暂不同意'));
    await tester.pumpAndSettle();
    expect(authorizer.calls, 0);
  });
  for (final result in ['success', 'cancel', 'failure']) {
    testWidgets('WeChat $result preserves the correct login state', (
      tester,
    ) async {
      final authorizer = _Authorizer();
      final gateway = _Gateway();
      if (result == 'failure') {
        gateway.failure = const ApiFailure('微信授权失败，请重新登录');
      }
      final store = await testStore(api: gateway, weChatAuthorizer: authorizer);
      await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth-consent')));
      await tester.tap(find.byKey(const ValueKey('auth-consent')));
      final button = find.byKey(const ValueKey('auth-wechat'));
      await tester.ensureVisible(button);
      final initialButtonRect = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(authorizer.calls, 1);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      authorizer.result.complete(result == 'cancel' ? null : 'wx-code');
      await tester.pumpAndSettle();
      expect(store.isAuthenticated, result == 'success');
      expect(
        gateway.calls.where((call) => call == 'WeChatLogin'),
        hasLength(result == 'cancel' ? 0 : 1),
      );
      if (result == 'success') {
        expect(find.byType(AppShell), findsOneWidget);
        expect(
          await store.storage.read('bojian.session'),
          contains('test-access'),
        );
      } else {
        expect(find.byType(SnackBar), findsNothing);
        if (result == 'cancel') {
          expect(find.text('已取消微信登录'), findsNothing);
          expect(find.byKey(const ValueKey('auth-status')), findsNothing);
          expect(find.byKey(const ValueKey('auth-error')), findsNothing);
          expect(tester.getRect(button), initialButtonRect);
        } else {
          final feedback = find.byKey(const ValueKey('auth-error'));
          expect(find.text('微信授权失败，请重新登录'), findsOneWidget);
          expect(
            tester.getTopLeft(feedback).dy,
            greaterThan(
              tester
                  .getBottomLeft(find.byKey(const ValueKey('auth-douyin')))
                  .dy,
            ),
          );
        }
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(find.byKey(const ValueKey('auth-wechat')), findsOneWidget);
        expect(find.byKey(const ValueKey('auth-submit')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('Late WeChat authorization cannot sign in after logout', () async {
    final authorizer = _Authorizer();
    final gateway = _Gateway();
    final store = await testStore(api: gateway, weChatAuthorizer: authorizer);
    addTearDown(store.dispose);
    final pending = store.signInWithWeChat();
    await Future<void>.delayed(Duration.zero);
    await store.endSession(remote: false);
    authorizer.result.complete('wx-code');
    await expectLater(pending, throwsA(isA<ApiFailure>()));
    expect(gateway.calls, isNot(contains('WeChatLogin')));
    expect(store.isAuthenticated, isFalse);
  });
  test(
    'Invalid server identity is rejected before saving a WeChat session',
    () async {
      final authorizer = _Authorizer()..result.complete('wx-code');
      final gateway = _Gateway()..invalidIdentity = true;
      final store = await testStore(api: gateway, weChatAuthorizer: authorizer);
      addTearDown(store.dispose);
      await expectLater(store.signInWithWeChat(), throwsA(isA<ApiFailure>()));
      expect(store.isAuthenticated, isFalse);
      expect(await store.storage.read('bojian.session'), isNull);
    },
  );
  for (final size in [const Size(320, 400), const Size(844, 360)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Login error is readable below buttons at $size/$brightness',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final authorizer = _Authorizer()..result.complete('wx-code');
          final gateway = _Gateway()
            ..failure = const ApiFailure('微信授权失败，请重新登录');
          final store = await testStore(
            api: gateway,
            weChatAuthorizer: authorizer,
          );
          await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
          await tester.pumpAndSettle();
          final consent = find.byKey(const ValueKey('auth-consent'));
          await tester.ensureVisible(consent);
          await tester.tap(consent);
          final button = find.byKey(const ValueKey('auth-wechat'));
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          final feedback = find.byKey(const ValueKey('auth-error'));
          await tester.ensureVisible(feedback);
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(feedback).dy,
            greaterThan(
              tester
                  .getBottomLeft(find.byKey(const ValueKey('auth-douyin')))
                  .dy,
            ),
          );
          expect(
            tester.getRect(feedback).bottom,
            lessThanOrEqualTo(size.height),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
