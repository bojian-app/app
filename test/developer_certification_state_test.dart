import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class DelayedIdentityGateway extends FakeGateway {
  bool delay = false;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final result = await super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
    if (delay && method == 'GetMeIdentityVerification') {
      started.complete();
      await release.future;
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final status in [
    'VERIFIED',
    'NOT_VERIFIED',
    'PENDING',
    'REJECTED',
    'EXPIRED',
  ]) {
    test(
      'Restored server status $status controls the badge and application',
      () async {
        final api = FakeGateway()
          ..documents['GetMeIdentityVerification'] = {
            'status': status,
            'valid_until': '2099-12-31',
          };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        expect(store.identityVerified, status == 'VERIFIED');
        expect(store.canApplyDeveloperVerification, status != 'VERIFIED');
      },
    );
  }

  test('An expired document no longer displays a certified badge', () async {
    final api = FakeGateway()
      ..documents['GetMeIdentityVerification'] = {
        'status': 'VERIFIED',
        'valid_until': '2000-01-01',
      };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    expect(store.identityVerified, false);
    expect(store.canApplyDeveloperVerification, true);
  });

  test(
    'Unavailable status does not fabricate certification and can be retried',
    () async {
      final api = FakeGateway()..failing = 'GetMeIdentityVerification';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      expect(store.identityVerified, false);
      expect(store.canApplyDeveloperVerification, false);
      api.failing = null;
      await store.load('identity');
      expect(store.canApplyDeveloperVerification, true);
    },
  );

  test(
    'A response started before success cannot restore the application entry',
    () async {
      final api = DelayedIdentityGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.delay = true;
      final loading = store.load('identity');
      await api.started.future;
      store.recordIdentityVerificationSuccess(
        verificationID: 123,
        expectedEpoch: store.epoch,
      );
      api.release.complete();
      await loading;
      expect(store.identityVerified, true);
      expect(store.canApplyDeveloperVerification, false);
    },
  );

  test('Signing out clears certification and rejects a late success from that account', () async {
    final api = FakeGateway()
      ..documents['GetMeIdentityVerification'] = {
        'status': 'VERIFIED',
        'valid_until': '2099-12-31',
      };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final oldEpoch = store.epoch;
    await store.endSession(remote: false);
    store.recordIdentityVerificationSuccess(
      verificationID: 123,
      expectedEpoch: oldEpoch,
    );
    expect(store.identityVerified, false);
    expect(store.canApplyDeveloperVerification, false);
    api.documents['GetMeIdentityVerification'] = {'status': 'NOT_VERIFIED'};
    await store.signIn('13812345678', '654321');
    await store.loadAll();
    expect(store.identityVerified, false);
    expect(store.canApplyDeveloperVerification, true);
  });

  test('A new app instance reads certification from the server', () async {
    final first = await testStore(authenticated: true);
    addTearDown(first.dispose);
    final api = FakeGateway()
      ..documents['GetMeIdentityVerification'] = {
        'status': 'VERIFIED',
        'valid_until': '2099-12-31',
      };
    final restored = AppStore(api: api, storage: first.storage);
    addTearDown(restored.dispose);
    expect(restored.canApplyDeveloperVerification, false);
    await restored.initialize();
    await restored.loadAll();
    expect(restored.identityVerified, true);
    expect(restored.canApplyDeveloperVerification, false);
  });
}
