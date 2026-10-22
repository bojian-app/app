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

class _AuthorizedWeChat implements WeChatAuthorizer {
  @override
  Future<String?> authorize() async => 'verified-code';
}

class _RegistrationGateway extends FakeGateway {
  bool failConfirmation = false;
  bool existing = false;

  Future<auth.LoginResponse> authorize(
    String channel,
    Map<String, String> headers,
  ) async {
    calls.add('Authorize$channel');
    if (existing) return super.login('', '', headers);
    return auth.LoginResponse(
      registrationRequired: true,
      registrationToken: 'private-registration-ticket',
      registrationExpiresInSeconds: 300,
    );
  }

  @override
  Future<auth.LoginResponse> loginWithWeChat(
    String code,
    Map<String, String> agreements,
    Map<String, String> headers,
  ) {
    expect(code, 'verified-code');
    return authorize('WECHAT', headers);
  }

  @override
  Future<auth.LoginResponse> loginWithDouyin(
    String code,
    Map<String, String> agreements,
    Map<String, String> headers,
  ) {
    expect(code, 'verified-code');
    return authorize('DOUYIN', headers);
  }

  @override
  Future<auth.LoginResponse> confirmRegistration(
    String token,
    Map<String, String> agreements,
    Map<String, String> headers,
  ) async {
    calls.add('ConfirmRegistration');
    expect(token, 'private-registration-ticket');
    expect(agreements, legalAgreementVersions);
    if (failConfirmation) throw const ApiFailure('注册失败，请稍后重试');
    return super.login('', '', headers);
  }
}

Future<void> _openLogin(
  WidgetTester tester,
  _RegistrationGateway gateway, {
  String channel = 'WECHAT',
}) async {
  final store = await testStore(
    api: gateway,
    weChatAuthorizer: _AuthorizedWeChat(),
    douyinAuthorizer: FakeDouyinAuthorizer(code: 'verified-code'),
  );
  await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
  await tester.pumpAndSettle();
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final consent = find.byKey(const ValueKey('auth-consent'));
  await tester.ensureVisible(consent);
  await tester.tap(consent);
  final button = find.byKey(
    ValueKey(channel == 'DOUYIN' ? 'auth-douyin' : 'auth-wechat'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final channel in ['WECHAT', 'DOUYIN']) {
    testWidgets(
      '$channel initial profile is loaded after confirmed registration',
      (tester) async {
        final gateway = _RegistrationGateway();
        gateway.documents['GetMe']!['nickname'] = '$channel 平台昵称';
        gateway.documents['GetMe']!['avatar_url'] =
            'https://storage.example/initial-avatar.jpg';
        await _openLogin(tester, gateway, channel: channel);
        await tester.tap(
          find.byKey(const ValueKey('auth-registration-confirm')),
        );
        await tester.pumpAndSettle();
        final store = tester.widget<MyApp>(find.byType(MyApp)).store!;
        expect(store.name, '$channel 平台昵称');
        expect(store.avatarURL, 'https://storage.example/initial-avatar.jpg');
        expect(gateway.calls, contains('ConfirmRegistration'));
        expect(gateway.calls, isNot(contains('PatchMe')));
        expect(find.byType(AppShell), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    for (final choice in ['cancel', 'back', 'confirm', 'failure']) {
      testWidgets(
        '$channel registration requires an explicit $choice decision',
        (tester) async {
          final gateway = _RegistrationGateway()
            ..failConfirmation = choice == 'failure';
          await _openLogin(tester, gateway, channel: channel);
          expect(find.text('该账号尚未注册'), findsOneWidget);
          expect(find.text('是否创建博简账号并完成登录？'), findsOneWidget);
          expect(gateway.calls, contains('Authorize$channel'));
          expect(gateway.calls, isNot(contains('ConfirmRegistration')));
          expect(find.byType(AppShell), findsNothing);
          if (choice == 'back') {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(
              find.byKey(
                ValueKey(
                  choice == 'cancel'
                      ? 'auth-registration-cancel'
                      : 'auth-registration-confirm',
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          final accepted = choice == 'confirm' || choice == 'failure';
          expect(
            gateway.calls.where((call) => call == 'ConfirmRegistration'),
            hasLength(accepted ? 1 : 0),
          );
          expect(
            find.byType(AppShell),
            choice == 'confirm' ? findsOneWidget : findsNothing,
          );
          if (choice == 'cancel' || choice == 'back') {
            expect(find.text('已取消注册，未创建账号'), findsNothing);
            expect(find.byKey(const ValueKey('auth-status')), findsNothing);
            expect(find.byKey(const ValueKey('auth-error')), findsNothing);
          } else if (choice == 'failure') {
            expect(find.text('注册失败，请稍后重试'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$channel existing accounts sign in without a registration dialog',
      (tester) async {
        final gateway = _RegistrationGateway()..existing = true;
        await _openLogin(tester, gateway, channel: channel);
        expect(
          find.byKey(const ValueKey('auth-registration-dialog')),
          findsNothing,
        );
        expect(gateway.calls, isNot(contains('ConfirmRegistration')));
        expect(find.byType(AppShell), findsOneWidget);
      },
    );
  }
  test('Pending registration never saves credentials without a confirmation callback', () async {
    final gateway = _RegistrationGateway();
    final store = await testStore(
      api: gateway,
      weChatAuthorizer: _AuthorizedWeChat(),
    );
    addTearDown(store.dispose);
    await expectLater(store.signInWithWeChat(), throwsA(isA<ApiFailure>()));
    expect(gateway.calls, isNot(contains('ConfirmRegistration')));
    expect(store.isAuthenticated, isFalse);
    expect(await store.storage.read('bojian.session'), isNull);
  });
  test(
    'Leaving the login session cancels a late registration decision',
    () async {
      final gateway = _RegistrationGateway();
      final store = await testStore(
        api: gateway,
        weChatAuthorizer: _AuthorizedWeChat(),
      );
      addTearDown(store.dispose);
      final decision = Completer<bool>();
      final pending = store.signInWithWeChat(
        confirmRegistration: () => decision.future,
      );
      await Future<void>.delayed(Duration.zero);
      await store.endSession(remote: false);
      decision.complete(true);
      await expectLater(pending, throwsA(isA<ApiFailure>()));
      expect(gateway.calls, isNot(contains('ConfirmRegistration')));
      expect(store.isAuthenticated, isFalse);
    },
  );
  testWidgets('Registration decision remains usable on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openLogin(tester, _RegistrationGateway());
    final confirm = find.byKey(const ValueKey('auth-registration-confirm'));
    await tester.ensureVisible(confirm);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(400));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('auth-registration-cancel')));
    await tester.pumpAndSettle();
  });
}
