import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:flutter_test/flutter_test.dart';

class StubClient extends MockClient {
  StubClient(this.response) : super((_) async => response);
  final http.Response response;
  http.Request? request;
  Uri? get uri => request?.url;
  String? get verb => request?.method;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest value) {
    request = value as http.Request;
    return super.send(value);
  }
}

http.Response stubResponse(int status, Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);
void main() {
  for (final entry in {
    'PostMePhoneSMSCodes': '/api/v1/me/phone/sms-codes',
    'PostMePhone': '/api/v1/me/phone',
  }.entries) {
    test('${entry.key} uses the authenticated binding route', () async {
      final client = StubClient(
        stubResponse(200, {
          'data': {'phone_masked': '138****8000'},
        }),
      );
      final api = BojianApi(client: client);
      final body = entry.key == 'PostMePhone'
          ? {'phone': '13800138000', 'code': '123456'}
          : {
              'phone': '13800138000',
              'captcha_token': 'proof',
              'purpose': 'BIND_PHONE',
            };
      await api.call(
        entry.key,
        body: body,
        headers: {'authorization': 'Bearer current-session'},
      );
      expect(client.uri?.path, entry.value);
      expect(client.verb, 'POST');
      expect(
        client.request?.headers['authorization'],
        'Bearer current-session',
      );
      expect(jsonDecode(client.request!.body), body);
      await api.close();
    });
  }
  for (final channel in ['phone', 'wechat', 'douyin']) {
    test(
      '$channel unregistered response preserves a confirmation-only state',
      () async {
        final client = StubClient(
          stubResponse(200, {
            'data': {
              'registration_required': true,
              'registration_token': 'pending-proof',
              'registration_expires_in_seconds': 300,
            },
          }),
        );
        final api = BojianApi(client: client);
        final result = switch (channel) {
          'phone' => await api.login('13800138000', '123456', {}),
          'wechat' => await api.loginWithWeChat('code', {
            'terms': '1.0',
            'privacy': '1.0',
          }, {}),
          _ => await api.loginWithDouyin('code', {
            'terms': '1.0',
            'privacy': '1.0',
          }, {}),
        };
        expect(result.registrationRequired, isTrue);
        expect(result.registrationToken, 'pending-proof');
        expect(result.accessToken, isEmpty);
        expect(result.refreshToken, isEmpty);
        expect(result.hasUser(), isFalse);
        await api.close();
      },
    );
  }
  test('Registration confirmation submits explicit consent and only the server proof', () async {
    final client = StubClient(
      stubResponse(200, {
        'data': {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'user': {'id': 23, 'public_id': 'BJ-TEST'},
        },
      }),
    );
    final api = BojianApi(client: client);
    final result = await api.confirmRegistration('pending-proof', {
      'terms': '1.0',
      'privacy': '1.0',
    }, {});
    expect(client.request?.url.path, '/api/v1/auth/registrations/confirm');
    expect(jsonDecode(client.request!.body), {
      'registration_token': 'pending-proof',
      'confirmed': true,
      'agreement_versions': {'terms': '1.0', 'privacy': '1.0'},
    });
    expect(result.user.id.toInt(), 23);
    await api.close();
  });
  test(
    'WeChat login exchanges only the authorization code and consent versions',
    () async {
      final client = StubClient(
        stubResponse(200, {
          'data': {
            'access_token': 'access',
            'refresh_token': 'refresh',
            'user': {'id': 23, 'public_id': 'BJ-TEST'},
          },
        }),
      );
      final api = BojianApi(client: client);
      final result = await api.loginWithWeChat(
        'one-time-code',
        {'terms': '1.0', 'privacy': '1.0'},
        {'x-device-id': 'test-device'},
      );
      expect(result.user.id.toInt(), 23);
      expect(result.accessToken, 'access');
      expect(client.request?.url.path, '/api/v1/auth/wechat/mobile/exchange');
      final body = jsonDecode(client.request!.body) as Map;
      expect(body, {
        'code': 'one-time-code',
        'agreement_versions': {'terms': '1.0', 'privacy': '1.0'},
      });
      await api.close();
    },
  );
  test(
    'Douyin login exchanges only the authorization code and consent versions',
    () async {
      final client = StubClient(
        stubResponse(200, {
          'data': {
            'access_token': 'access',
            'refresh_token': 'refresh',
            'user': {'id': 23, 'public_id': 'BJ-TEST'},
          },
        }),
      );
      final api = BojianApi(client: client);
      final result = await api.loginWithDouyin(
        'one-time-code',
        {'terms': '1.0', 'privacy': '1.0'},
        {'x-device-id': 'test-device'},
      );
      expect(result.user.id.toInt(), 23);
      expect(result.accessToken, 'access');
      expect(client.request?.url.path, '/api/v1/auth/douyin/mobile/exchange');
      final body = jsonDecode(client.request!.body) as Map;
      expect(body, {
        'code': 'one-time-code',
        'agreement_versions': {'terms': '1.0', 'privacy': '1.0'},
      });
      await api.close();
    },
  );
  for (final status in [null, 'SUBMITTED', 'DELIVERED']) {
    test('SMS response preserves delivery state $status', () async {
      final data = <String, dynamic>{'retry_after_seconds': 60};
      if (status != null) data['delivery_status'] = status;
      final client = StubClient(stubResponse(202, {'data': data}));
      final api = BojianApi(client: client);
      final result = await api.sendSMS('13800138000', 'captcha', {});
      expect(result.deliveryStatus, status ?? '');
      expect(result.retryAfterSeconds, 60);
      await api.close();
    });
  }
  test(
    'SMS delivery error preserves the server failure without a success result',
    () async {
      final api = BojianApi(
        client: StubClient(
          stubResponse(503, {
            'error': {'code': 'SMS_DELIVERY_FAILED', 'message': '短信发送失败，请稍后重试'},
          }),
        ),
      );
      await expectLater(
        api.sendSMS('13800138000', 'captcha', {}),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.code,
            'code',
            'SMS_DELIVERY_FAILED',
          ),
        ),
      );
      await api.close();
    },
  );
  test(
    'Business requests preserve /api/v1, revision and auth headers',
    () async {
      final client = StubClient(
        stubResponse(200, {
          'data': {'id': 4},
        }),
      );
      await (() async {
        final api = BojianApi(client: client);
        await api.call(
          'PatchResumesId',
          path: {'id': '4'},
          headers: {'authorization': 'Bearer token', 'if-match': 'revision-7'},
          body: {'title': '简历'},
        );
        expect(
          client.uri.toString(),
          'https://bojian.kelance.cn/api/v1/resumes/4',
        );
        expect(client.verb, 'PATCH');
        expect(client.request!.headers['if-match'], 'revision-7');
        expect(client.request!.headers['authorization'], 'Bearer token');
        expect(jsonDecode(client.request!.body), {'title': '简历'});
        expect(client.request!.followRedirects, isFalse);
        await api.close();
      })();
    },
  );
  test('Captcha uses the HTTP auth path and maps image fields', () async {
    final client = StubClient(
      stubResponse(201, {
        'data': {
          'id': 'challenge',
          'kind': 'SLIDE',
          'piece_y': 35,
          'max_x': 268,
          'master_image_data_url': 'master',
          'thumb_image_data_url': 'thumb',
        },
      }),
    );
    await (() async {
      final api = BojianApi(client: client);
      final captcha = await api.createCaptcha({});
      expect(client.uri!.path, '/api/v1/auth/captchas');
      expect(client.verb, 'POST');
      expect(client.uri!.queryParameters['type'], 'SLIDE');
      expect(captcha.pieceY, 35);
      expect(captcha.maxX, 268);
      expect(captcha.id, 'challenge');
      expect(captcha.masterImageDataUrl, 'master');
      expect(captcha.thumbImageDataUrl, 'thumb');
      await api.close();
    })();
  });
  test('Puzzle verification sends x rather than rotation angle', () async {
    final client = StubClient(
      stubResponse(200, {
        'data': {'captcha_token': 'ok'},
      }),
    );
    final api = BojianApi(client: client);
    final result = await api.verifyCaptcha('puzzle', 160, {});
    expect(client.uri!.path, '/api/v1/auth/captchas/puzzle/verify');
    expect(jsonDecode(client.request!.body), {'x': 160});
    expect(result.captchaToken, 'ok');
    await api.close();
  });
  test('HTTP 401 preserves refresh eligibility and server error', () async {
    final client = StubClient(
      stubResponse(401, {
        'error': {'code': 'TOKEN_EXPIRED', 'message': '登录已过期'},
      }),
    );
    await (() async {
      final api = BojianApi(client: client);
      await expectLater(
        api.call('GetMe'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.unauthenticated, 'refresh', true)
              .having((e) => e.code, 'code', 'TOKEN_EXPIRED'),
        ),
      );
      await api.close();
    })();
  });
}
