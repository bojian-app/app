import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_qr_login_controller.dart';
import 'package:bojian_mobile/app_qr_login_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

final qrID = 'a' * 43;
final qrToken = 'b' * 43;
String get qrContent =>
    '$appQRWebsite/app-login#v=1&session=$qrID&token=$qrToken';
Map<String, dynamic> qrResponse([String status = 'SCANNED']) => {
  'session_id': qrID,
  'status': status,
  'website': appQRWebsite,
  'client_name': 'Windows · Chrome',
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 2))
      .toUtc()
      .toIso8601String(),
};

class QRGateway extends FakeGateway {
  Completer<ApiDocument>? scanResult;
  ApiFailure failure = const ApiFailure('网络不可用');
  final bodies = <String, Map<String, dynamic>?>{};
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method.startsWith('PostMeAppQR')) {
      calls.add(method);
      bodies[method] = body;
      if (failing == method) return Future.error(failure);
      if (method.endsWith('Scan') && scanResult != null) {
        return scanResult!.future;
      }
      return Future.value(
        ApiDocument(
          qrResponse(
            method.endsWith('Confirm')
                ? 'CONFIRMED'
                : method.endsWith('Cancel')
                ? 'CANCELED'
                : 'SCANNED',
          ),
        ),
      );
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
  test('Expired server response cannot be confirmed', () async {
    final api = QRGateway()..scanResult = Completer<ApiDocument>();
    final store = await testStore(authenticated: true, api: api);
    final controller = AppQRLoginController(AppQRLoginService(store));
    addTearDown(store.dispose);
    addTearDown(controller.dispose);
    final pending = controller.scan(qrContent);
    api.scanResult!.complete(
      ApiDocument(
        qrResponse()
          ..['created_at'] = DateTime.now()
              .subtract(const Duration(minutes: 3))
              .toUtc()
              .toIso8601String()
          ..['expires_at'] = DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .toIso8601String(),
      ),
    );
    await pending;
    await controller.confirm();
    expect(controller.phase, AppQRLoginPhase.expired);
    expect(controller.canConfirm, isFalse);
    expect(api.calls, isNot(contains('PostMeAppQRSessionsSessionConfirm')));
  });

  test('Only official versioned, unambiguous App QR payloads are accepted', () {
    final parsed = AppQRLoginCode.parse(qrContent);
    expect(parsed.sessionID, qrID);
    expect(parsed.scanToken, qrToken);
    for (final invalid in [
      'https://example.com/app-login#v=1&session=$qrID&token=$qrToken',
      qrContent.replaceFirst('https:', 'http:'),
      qrContent.replaceFirst(
        'bojian.kelance.cn',
        'bojian.kelance.cn.evil.test',
      ),
      qrContent.replaceFirst('/app-login', '/app-login/'),
      qrContent.replaceFirst('#', '?x=1#'),
      qrContent.replaceFirst('v=1', 'v=2'),
      '$qrContent&token=$qrToken',
      '$qrContent&extra=1',
      qrContent.replaceFirst(qrToken, 'short'),
      '$appQRWebsite:8443/app-login#v=1&session=$qrID&token=$qrToken',
      '$appQRWebsite/app-login#v=1&session=$qrID&token=%GG',
    ]) {
      expect(
        () => AppQRLoginCode.parse(invalid),
        throwsA(isA<ApiFailure>()),
        reason: invalid,
      );
    }
  });

  test(
    'Scanning claims once and never authorizes without explicit confirmation',
    () async {
      final api = QRGateway()..scanResult = Completer<ApiDocument>();
      final store = await testStore(authenticated: true, api: api);
      final controller = AppQRLoginController(AppQRLoginService(store));
      addTearDown(store.dispose);
      addTearDown(controller.dispose);
      final first = controller.scan(qrContent);
      await controller.scan(qrContent);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.where((s) => s.endsWith('SessionScan')).length, 1);
      expect(controller.canConfirm, isFalse);
      api.scanResult!.complete(ApiDocument(qrResponse()));
      await first;
      expect(controller.phase, AppQRLoginPhase.confirmation);
      expect(api.calls, isNot(contains('PostMeAppQRSessionsSessionConfirm')));
      await controller.confirm();
      expect(controller.phase, AppQRLoginPhase.success);
      expect(api.bodies['PostMeAppQRSessionsSessionConfirm'], {
        'scan_token': qrToken,
        'confirmed': true,
      });
      expect(store.isAuthenticated, isTrue);
    },
  );

  test('Cancel and confirmation retry preserve explicit choices', () async {
    final api = QRGateway();
    final store = await testStore(authenticated: true, api: api);
    final controller = AppQRLoginController(AppQRLoginService(store));
    addTearDown(store.dispose);
    addTearDown(controller.dispose);
    await controller.scan(qrContent);
    api.failing = 'PostMeAppQRSessionsSessionConfirm';
    await controller.confirm();
    expect(controller.phase, AppQRLoginPhase.confirmation);
    expect(controller.error, contains('网络不可用'));
    api.failing = null;
    await controller.cancel();
    expect(controller.phase, AppQRLoginPhase.canceled);
    await controller.confirm();
    expect(controller.phase, AppQRLoginPhase.canceled);
  });

  test('Wrong QR and switched account cannot authorize a browser', () async {
    final api = QRGateway();
    final store = await testStore(authenticated: true, api: api);
    final controller = AppQRLoginController(AppQRLoginService(store));
    addTearDown(store.dispose);
    addTearDown(controller.dispose);
    await controller.scan('https://example.com');
    expect(controller.phase, AppQRLoginPhase.error);
    expect(api.calls.where((s) => s.startsWith('PostMeAppQR')), isEmpty);
    controller.rescan();
    await controller.scan(qrContent);
    store.epoch++;
    store.changed();
    await controller.confirm();
    expect(controller.phase, AppQRLoginPhase.sessionChanged);
    expect(controller.session, isNull);
    expect(api.calls, isNot(contains('PostMeAppQRSessionsSessionConfirm')));
  });

  test(
    'Late scan after disposal is canceled without granting authorization',
    () async {
      final api = QRGateway()..scanResult = Completer<ApiDocument>();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final controller = AppQRLoginController(AppQRLoginService(store));
      final pending = controller.scan(qrContent);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      api.scanResult!.complete(ApiDocument(qrResponse()));
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, contains('PostMeAppQRSessionsSessionCancel'));
      expect(api.calls, isNot(contains('PostMeAppQRSessionsSessionConfirm')));
    },
  );

  test('Mismatched server identity and website are rejected', () {
    for (final data in [
      qrResponse()..['session_id'] = 'wrong',
      qrResponse()..['website'] = 'https://evil.test',
    ]) {
      expect(
        () => AppQRLoginSession.fromMap(data, qrID),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
}
