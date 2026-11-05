import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/api/generated/auth.pb.dart' as auth;
import 'package:bojian_mobile/app_environment.dart';
import 'package:bojian_mobile/captcha_dialog.dart';
import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class LocalPhoneGateway extends FakeGateway {
  final response = Completer<String>();

  @override
  Future<CaptchaChallenge> createCaptcha(Map<String, String> headers) =>
      throw StateError('The local test phone must not open a captcha');

  @override
  Future<auth.SMSResponse> sendSMS(
    String phone,
    String token,
    Map<String, String> headers,
  ) async {
    calls.add('SendSMS');
    expect(phone, '13800138000');
    expect(token, isEmpty);
    return auth.SMSResponse(
      retryAfterSeconds: 60,
      testCode: await response.future,
    );
  }

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostMePhoneSMSCodes') {
      calls.add(method);
      expect(body?['phone'], '13800138000');
      expect(body?['purpose'], 'BIND_PHONE');
      expect(body?['captcha_token'], isEmpty);
      return ApiDocument({
        'retry_after_seconds': 60,
        'test_code': await response.future,
      });
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

String fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

void main() {
  for (final login in [true, false]) {
    testWidgets(
      'Local ${login ? "login" : "binding"} waits for issued code then fills it',
      (tester) async {
        final api = LocalPhoneGateway();
        api.documents['GetMe']!.remove('phone_masked');
        final store = await testStore(authenticated: !login, api: api);
        await tester.pumpWidget(
          MyApp(
            startupAnimationEnabled: false,
            bannerAdsEnabled: false,
            store: store,
          ),
        );
        await tester.pumpAndSettle();
        final prefix = login ? 'auth' : 'phone-binding';
        expect(fieldText(tester, '$prefix-phone'), '13800138000');
        expect(fieldText(tester, '$prefix-code'), isEmpty);
        if (login) {
          await tester.tap(find.byKey(const ValueKey('auth-consent')));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(
          find.byKey(ValueKey('$prefix-request-code')),
        );
        await tester.tap(find.byKey(ValueKey('$prefix-request-code')));
        await tester.pump();
        expect(fieldText(tester, '$prefix-code'), isEmpty);
        expect(find.byType(CaptchaDialog), findsNothing);
        api.response.complete('654321');
        await tester.pumpAndSettle();
        expect(fieldText(tester, '$prefix-code'), '654321');
        expect(find.text('测试验证码已自动填入，未发送短信'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !AppEnvironment.isLocal,
    );
  }
}
