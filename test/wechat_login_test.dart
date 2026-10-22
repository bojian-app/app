import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/wechat_login.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluwx_no_pay/fluwx_no_pay.dart';

import 'support/fake_gateway.dart';

class _Subscription with FluwxCancelable {
  _Subscription(this.onCancel);
  final VoidCallback onCancel;
  @override
  void cancel() => onCancel();
}

class _SDK implements Fluwx {
  bool installed = true, registered = true, launched = true;
  bool autoRespond = true, removed = false;
  int responseCode = 0, requests = 0;
  String? code = 'one-time-code';
  String? requestState;
  WeChatResponseSubscriber? subscriber;
  @override
  Future<bool> registerApi({
    required String appId,
    bool doOnIOS = true,
    bool doOnAndroid = true,
    String? universalLink,
  }) async => registered;
  @override
  Future<bool> get isWeChatInstalled async => installed;
  @override
  FluwxCancelable addSubscriber(WeChatResponseSubscriber listener) {
    subscriber = listener;
    return _Subscription(() {
      removed = true;
      subscriber = null;
    });
  }

  @override
  Future<bool> authBy({required AuthType which}) async {
    requests++;
    final request = which as NormalAuth;
    expectSync(request.scope, 'snsapi_userinfo');
    expectSync(request.nonAutomatic, isTrue);
    expectSync(request.state.length, greaterThanOrEqualTo(32));
    requestState = request.state;
    if (autoRespond) respond();
    return launched;
  }

  void respond({String? state, bool omitState = false}) {
    subscriber?.call(
      WeChatAuthResponse.fromMap({
        'type': 1,
        'errCode': responseCode,
        if (!omitState) 'state': state ?? requestState,
        'code': code,
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'Native WeChat requires confirmation on every $platform login',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final sdk = _SDK();
          final authorizer = NativeWeChatAuthorizer(sdk);
          expect(await authorizer.authorize(), 'one-time-code');
          final firstState = sdk.requestState;
          expect(sdk.removed, isTrue);
          sdk.removed = false;
          expect(await authorizer.authorize(), 'one-time-code');
          expect(sdk.requestState, isNot(firstState));
          expect(sdk.requests, 2);
          expect(sdk.removed, isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
  testWidgets(
    'Cancel returns no code and removes the authorization subscriber',
    (tester) async {
      final sdk = _SDK()..responseCode = -2;
      expect(await NativeWeChatAuthorizer(sdk).authorize(), isNull);
      expect(sdk.removed, isTrue);
    },
  );
  for (final condition in [
    'not-installed',
    'denied',
    'no-code',
    'not-launched',
  ]) {
    testWidgets(
      'Native WeChat rejects $condition without accepting an identity',
      (tester) async {
        final sdk = _SDK();
        switch (condition) {
          case 'not-installed':
            sdk.installed = false;
          case 'denied':
            sdk.responseCode = -4;
          case 'no-code':
            sdk.code = null;
          case 'not-launched':
            sdk.launched = false;
        }
        await expectLater(
          NativeWeChatAuthorizer(sdk).authorize(),
          throwsA(isA<ApiFailure>()),
        );
        expect(sdk.subscriber, isNull);
      },
    );
  }

  testWidgets('Returning without a callback cancels and releases the request', (
    tester,
  ) async {
    final sdk = _SDK()..autoRespond = false;
    var completed = false;
    final pending = NativeWeChatAuthorizer(sdk).authorize().then((code) {
      completed = true;
      return code;
    });
    await tester.pump();
    expect(sdk.requests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 999));
    expect(completed, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(await pending, isNull);
    expect(sdk.removed, isTrue);
  });

  for (final callbackTiming in ['background', 'after-return']) {
    testWidgets('A valid $callbackTiming callback wins over return fallback', (
      tester,
    ) async {
      final sdk = _SDK()..autoRespond = false;
      final pending = NativeWeChatAuthorizer(sdk).authorize();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      if (callbackTiming == 'after-return') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
      sdk.respond();
      await tester.pump();
      expect(await pending, 'one-time-code');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(sdk.removed, isTrue);
    });
  }

  testWidgets('iOS temporary focus loss does not cancel authorization', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final sdk = _SDK()..autoRespond = false;
      var completed = false;
      final pending = NativeWeChatAuthorizer(sdk).authorize().then((code) {
        completed = true;
        return code;
      });
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(completed, isFalse);
      sdk.respond();
      expect(await pending, 'one-time-code');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android chooser cancellation needs no paused lifecycle event', (
    tester,
  ) async {
    final sdk = _SDK()..autoRespond = false;
    var completed = false;
    final pending = NativeWeChatAuthorizer(sdk).authorize().then((code) {
      completed = true;
      return code;
    });
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 15));
    expect(completed, isFalse, reason: 'Do not cancel while choosing a WeChat');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(
      completed,
      isTrue,
      reason: 'Cancelling the chooser must release login',
    );
    expect(await pending, isNull);
    expect(sdk.removed, isTrue);
  });

  testWidgets(
    'Choosing a WeChat after a focus return keeps its authorization pending',
    (tester) async {
      final sdk = _SDK()..autoRespond = false;
      var completed = false;
      final pending = NativeWeChatAuthorizer(sdk).authorize().then((code) {
        completed = true;
        return code;
      });
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 2));
      expect(completed, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));
      expect(completed, isFalse);
      sdk.respond();
      expect(await pending, 'one-time-code');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('A callback queued after chooser return wins over cancellation', (
    tester,
  ) async {
    final sdk = _SDK()..autoRespond = false;
    final pending = NativeWeChatAuthorizer(sdk).authorize();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 250));
    sdk.respond();
    expect(await pending, 'one-time-code');
    await tester.pump(const Duration(seconds: 1));
    expect(sdk.removed, isTrue);
  });

  testWidgets('Return fallback pauses while the app is backgrounded again', (
    tester,
  ) async {
    final sdk = _SDK()..autoRespond = false;
    var completed = false;
    final pending = NativeWeChatAuthorizer(sdk).authorize().then((code) {
      completed = true;
      return code;
    });
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(completed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(await pending, isNull);
  });

  testWidgets('A stale callback cannot finish a retry after cancellation', (
    tester,
  ) async {
    final sdk = _SDK()..autoRespond = false;
    final authorizer = NativeWeChatAuthorizer(sdk);
    final first = authorizer.authorize();
    await tester.pump();
    final firstState = sdk.requestState;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(await first, isNull);

    var completed = false;
    final second = authorizer.authorize().then((code) {
      completed = true;
      return code;
    });
    await tester.pump();
    expect(sdk.requestState, isNot(firstState));
    sdk.respond(state: firstState);
    await tester.pump();
    expect(completed, isFalse);
    sdk.respond();
    expect(await second, 'one-time-code');
    expect(sdk.requests, 2);
  });

  testWidgets('Unmatched callbacks cannot sign in and still time out', (
    tester,
  ) async {
    final sdk = _SDK()..autoRespond = false;
    final pending = NativeWeChatAuthorizer(sdk).authorize();
    final expected = expectLater(
      pending,
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.message,
          'message',
          '微信授权超时，请重试',
        ),
      ),
    );
    await tester.pump();
    sdk.respond(state: 'other-request');
    await tester.pump(const Duration(minutes: 2));
    await expected;
    expect(sdk.removed, isTrue);
  });

  testWidgets('SDK cancellation without a state returns immediately', (
    tester,
  ) async {
    final sdk = _SDK()
      ..autoRespond = false
      ..responseCode = -2;
    final pending = NativeWeChatAuthorizer(sdk).authorize();
    await tester.pump();
    sdk.respond(omitState: true);
    expect(await pending, isNull);
    expect(sdk.removed, isTrue);
  });

  for (final interruption in [
    AppLifecycleState.paused,
    AppLifecycleState.inactive,
  ]) {
    testWidgets(
      'Missing callback after $interruption restores both login buttons and retry',
      (tester) async {
        final sdk = _SDK()..autoRespond = false;
        final gateway = FakeGateway();
        final store = await testStore(
          api: gateway,
          weChatAuthorizer: NativeWeChatAuthorizer(sdk),
        );
        await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('auth-consent')));
        await tester.tap(find.byKey(const ValueKey('auth-consent')));
        final wechat = find.byKey(const ValueKey('auth-wechat'));
        final douyin = find.byKey(const ValueKey('auth-douyin'));
        await tester.ensureVisible(wechat);
        await tester.tap(wechat);
        await tester.pumpAndSettle();
        expect(find.text('正在等待微信授权…'), findsOneWidget);
        expect(tester.widget<FilledButton>(wechat).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(douyin).onPressed, isNull);

        tester.binding.handleAppLifecycleStateChanged(interruption);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('正在等待微信授权…'), findsNothing);
        expect(find.text('已取消微信登录'), findsNothing);
        expect(find.byKey(const ValueKey('auth-status')), findsNothing);
        expect(find.byKey(const ValueKey('auth-error')), findsNothing);
        expect(tester.widget<FilledButton>(wechat).onPressed, isNotNull);
        expect(tester.widget<OutlinedButton>(douyin).onPressed, isNotNull);
        expect(store.isAuthenticated, isFalse);
        expect(gateway.calls, isNot(contains('WeChatLogin')));

        await tester.ensureVisible(wechat);
        await tester.tap(wechat);
        await tester.pumpAndSettle();
        expect(sdk.requests, 2);
        sdk.responseCode = -2;
        sdk.respond();
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(wechat).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
