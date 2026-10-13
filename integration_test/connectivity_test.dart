import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Phone can reach HTTP API and receive a captcha', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final api = BojianApi();
    addTearDown(api.close);
    late ApiDocument health;
    try {
      health = await api.call('GetHealth');
    } on ApiFailure catch (e) {
      debugPrint('Connection diagnostic: ${e.cause}');
      rethrow;
    }
    expect(health.data, isNotEmpty);
    final captcha = await api.createCaptcha({
      'x-platform': 'ANDROID',
      'x-device-id': 'mobile-connectivity-probe',
      'x-app-version': '1.0.0',
    });
    expect(captcha.id, isNotEmpty);
    expect(captcha.masterImageDataUrl, isNotEmpty);
    expect(captcha.maxX, greaterThan(0));
    expect(captcha.pieceY, greaterThanOrEqualTo(0));
    await expectLater(
      api.refresh('invalid-mobile-probe-token', {
        'x-platform': 'ANDROID',
        'x-device-id': 'mobile-connectivity-probe',
        'x-app-version': '1.0.0',
      }),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'auth status',
          'SESSION_INVALID',
        ),
      ),
    );
    binding.reportData = {
      'httpConnected': true,
      'slideCaptchaReceived': true,
      'androidHeadersAccepted': true,
    };
  });
}
