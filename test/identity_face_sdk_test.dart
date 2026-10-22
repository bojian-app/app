import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/identity_face_sdk.dart';
import 'package:bojian_mobile/identity_verification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.kelance.bojian/identity_face');
  final calls = <MethodCall>[];
  IdentityFaceSession session() => IdentityFaceSession(
    id: 'x' * 43,
    status: IdentityFaceStatus.pending,
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    nativeToken: 'scoped-token',
    planID: '27030',
  );
  setUp(() => calls.clear());
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'Availability check does not initialize or launch face collection',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {'available': true, 'plan_id': '27030'};
          });
      await IdentityFaceSdk().checkAvailable();
      expect(calls.map((c) => c.method), ['available']);
    },
  );
  test(
    'Native receives scoped token and consent; cancellation is not completion',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {'session_id': 'x' * 43, 'cancelled': true};
          });
      expect(
        await IdentityFaceSdk().verify(
          session(),
          accentColor: 0xFF2867EE,
          dark: false,
        ),
        false,
      );
      final args = calls.single.arguments as Map;
      expect(args['consent'], true);
      expect(args['match_source'], 0);
      expect(args['native_token'], 'scoped-token');
      expect(args.containsKey('access_token'), false);
      expect(args.containsKey('secret_key'), false);
    },
  );
  test('Mismatched native callback cannot complete another session', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => {'session_id': 'other', 'cancelled': false},
        );
    await expectLater(
      IdentityFaceSdk().verify(session(), accentColor: 0xFF2867EE, dark: true),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'Cancel invalidates an in-flight native result and targets that session',
    () async {
      final release = Completer<Object?>();
      final started = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'verify') {
              started.complete();
              return release.future;
            }
            return null;
          });
      final sdk = IdentityFaceSdk();
      final verify = sdk.verify(
        session(),
        accentColor: 0xFF2867EE,
        dark: false,
      );
      final rejected = expectLater(verify, throwsA(isA<ApiFailure>()));
      await started.future;
      await sdk.cancel();
      expect(calls.last.method, 'cancel');
      expect((calls.last.arguments as Map)['session_id'], 'x' * 43);
      release.complete({'session_id': 'x' * 43, 'cancelled': false});
      await rejected;
    },
  );
  test(
    'A late callback cannot clear a retried attempt of the same session',
    () async {
      final first = Completer<Object?>(), second = Completer<Object?>();
      final firstStarted = Completer<void>(), secondStarted = Completer<void>();
      var count = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'verify') return null;
            count++;
            if (count == 1) {
              firstStarted.complete();
              return first.future;
            }
            secondStarted.complete();
            return second.future;
          });
      final sdk = IdentityFaceSdk();
      final old = sdk.verify(session(), accentColor: 0xFF2867EE, dark: false);
      final rejected = expectLater(old, throwsA(isA<ApiFailure>()));
      await firstStarted.future;
      await sdk.cancel();
      final retry = sdk.verify(session(), accentColor: 0xFF2867EE, dark: false);
      await secondStarted.future;
      first.complete({'session_id': 'x' * 43, 'cancelled': false});
      await rejected;
      await expectLater(
        sdk.verify(session(), accentColor: 0xFF2867EE, dark: false),
        throwsA(isA<ApiFailure>()),
      );
      second.complete({'session_id': 'x' * 43, 'cancelled': false});
      expect(await retry, true);
    },
  );
}
