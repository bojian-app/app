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
