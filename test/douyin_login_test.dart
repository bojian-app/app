import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/douyin_login.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bojian.test/douyin');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Only matching state returns a code, and every request uses a fresh nonce',
    () async {
      final states = <String>[];
      final cancelled = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'cancel') {
          cancelled.add(args['state'] as String);
          return null;
        }
        expect(args['clientKey'], NativeDouyinAuthorizer.clientKey);
        expect(args['scope'], 'user_info');
        expect(args['redirectUri'], 'https://bojian.kelance.cn/douyin/');
        expect(args.keys, isNot(contains('clientSecret')));
        expect(args['state'], matches(RegExp(r'^[a-f0-9]{48}$')));
        states.add(args['state'] as String);
        return {'state': args['state'], 'code': 'one-time-code'};
      });
      final authorizer = NativeDouyinAuthorizer(channel: channel);
      expect(await authorizer.authorize(), 'one-time-code');
      expect(await authorizer.authorize(), 'one-time-code');
      expect(states.toSet(), hasLength(2));
      expect(cancelled, states);
    },
  );

  for (final condition in [
    'cancel',
    'wrong-state',
    'no-code',
    'not-installed',
    'denied',
  ]) {
    test(
      'Native Douyin handles $condition without accepting a false identity',
      () async {
        var cleaned = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') {
            cleaned = true;
            return null;
          }
          final state = (call.arguments as Map)['state'];
          if (condition == 'not-installed' || condition == 'denied') {
            throw PlatformException(
              code: condition == 'denied' ? 'DENIED' : 'NOT_INSTALLED',
            );
          }
          return {
            'state': condition == 'wrong-state' ? 'other-request' : state,
            if (condition == 'cancel') 'cancelled': true,
            if (condition != 'no-code') 'code': 'one-time-code',
          };
        });
        final future = NativeDouyinAuthorizer(channel: channel).authorize();
        if (condition == 'cancel') {
          expect(await future, isNull);
        } else {
          await expectLater(future, throwsA(isA<ApiFailure>()));
        }
        expect(cleaned, isTrue);
      },
    );
  }

  for (final example in [
    (-12, '抖音授权网络异常，请稍后重试（-12）'),
    (7, '操作过于频繁，请稍后重试（7）'),
    (10004, '抖音登录权限暂不可用，请稍后重试（10004）'),
    (10011, '抖音暂时无法验证此应用，请稍后重试（10011）'),
    (10017, '抖音暂时无法验证此应用，请稍后重试（10017）'),
    (-1, '抖音授权失败，请重试（-1）'),
  ]) {
    test(
      'Official SDK error ${example.$1} is preserved without raw SDK data',
      () async {
        var cleaned = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') {
            cleaned = true;
            return null;
          }
          throw PlatformException(
            code: 'AUTH_FAILED',
            message: 'raw-provider-text-must-not-be-shown',
            details: {
              'providerCode': example.$1,
              'authCode': 'sensitive-test-code',
            },
          );
        });
        await expectLater(
          NativeDouyinAuthorizer(channel: channel).authorize(),
          throwsA(
            isA<ApiFailure>()
                .having((error) => error.message, 'message', example.$2)
                .having(
                  (error) => error.code,
                  'code',
                  'DOUYIN_SDK_${example.$1}',
                ),
          ),
        );
        expect(cleaned, isTrue);
      },
    );
  }

  for (final nativeCode in ['CANCELLED', 'AUTH_FAILED']) {
    test(
      'Native cancellation $nativeCode returns no authorization code',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancel') return null;
          throw PlatformException(
            code: nativeCode,
            details: {'providerCode': -2},
          );
        });
        expect(
          await NativeDouyinAuthorizer(channel: channel).authorize(),
          isNull,
        );
      },
    );
  }

  test(
    'Malformed provider details never become a user-visible error',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancel') return null;
        throw PlatformException(
          code: 'AUTH_FAILED',
          details: {'providerCode': 'sensitive-test-code'},
        );
      });
      await expectLater(
        NativeDouyinAuthorizer(channel: channel).authorize(),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.message,
            'message',
            '抖音授权失败，请重试',
          ),
        ),
      );
    },
  );

  test('Pending authorization blocks duplicates and timeout releases the native request', () async {
    final completion = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    var calls = 0;
    var cleaned = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        cleaned = true;
        return null;
      }
      calls++;
      started.complete();
      return completion.future;
    });
    final authorizer = NativeDouyinAuthorizer(
      channel: channel,
      timeout: const Duration(milliseconds: 50),
    );
    final first = authorizer.authorize();
    final check = expectLater(
      first,
      throwsA(
        isA<ApiFailure>().having((e) => e.message, 'message', '抖音授权超时，请重试'),
      ),
    );
    await started.future;
    await expectLater(authorizer.authorize(), throwsA(isA<ApiFailure>()));
    await check;
    expect(calls, 1);
    expect(cleaned, isTrue);
    completion.complete({'state': 'old-request', 'code': 'late-code'});
  });
}
