import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'generated/auth.pb.dart' as auth;
import 'http_routes.dart';

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.code,
    this.unauthenticated = false,
    this.cause,
  });
  final String message;
  final String? code;
  final bool unauthenticated;
  final Object? cause;
  @override
  String toString() => message;
}

class ApiDocument {
  ApiDocument(this.data, {this.nextCursor = ''});
  final Map<String, dynamic> data;
  final String nextCursor;
}

abstract class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSessionStorage implements SessionStorage {
  final storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String? value) => value == null
      ? storage.delete(key: key)
      : storage.write(key: key, value: value);
}

class CaptchaChallenge {
  const CaptchaChallenge({
    required this.id,
    required this.masterImageDataUrl,
    required this.thumbImageDataUrl,
    required this.pieceY,
    required this.maxX,
  });
  final String id, masterImageDataUrl, thumbImageDataUrl;
  final int pieceY, maxX;
}

abstract class ApiGateway {
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  });
  Future<CaptchaChallenge> createCaptcha(Map<String, String> headers);
  Future<auth.CaptchaVerification> verifyCaptcha(
    String id,
    int position,
    Map<String, String> headers,
  );
  Future<auth.SMSResponse> sendSMS(
    String phone,
    String captchaToken,
    Map<String, String> headers,
  );
  Future<auth.LoginResponse> login(
    String phone,
    String code,
    Map<String, String> headers,
  );
  Future<auth.LoginResponse> loginWithWeChat(
    String code,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  );
  Future<auth.LoginResponse> confirmRegistration(
    String registrationToken,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  );
  Future<auth.LoginResponse> loginWithDouyin(
    String code,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  );
  Future<auth.TokenResponse> refresh(String token, Map<String, String> headers);
  Future<void> close();
}

class BojianApi implements ApiGateway {
  factory BojianApi({Uri? baseURL, http.Client? client}) {
    final address =
        baseURL ??
        Uri.parse(
          const String.fromEnvironment(
            'BOJIAN_API_BASE_URL',
            defaultValue: 'https://bojian.kelance.cn/api/v1',
          ),
        );
    if (address.scheme != 'https' ||
        address.host.isEmpty ||
        address.hasQuery ||
        address.hasFragment ||
        address.userInfo.isNotEmpty ||
        address.path.replaceFirst(RegExp(r'/$'), '') != '/api/v1') {
      throw const ApiFailure('服务地址配置无效，需要 HTTPS 地址及 /api/v1 前缀');
    }
    final transport =
        client ??
        (Platform.isAndroid
            ? CronetClient.fromCronetEngine(
                CronetEngine.build(
                  enableHttp2: true,
                  enableQuic: true,
                  quicHints: [(address.host, address.port, address.port)],
                ),
                closeEngine: true,
              )
            : IOClient(
                HttpClient()..connectionTimeout = const Duration(seconds: 15),
              ));
    return BojianApi._(address, transport);
  }
  BojianApi._(this.baseURL, this.client);
  final Uri baseURL;
  final http.Client client;

  Future<ApiDocument> send(
    String verb,
    String route, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final prefix = baseURL.path.replaceFirst(RegExp(r'/$'), '');
    final uri = baseURL.replace(
      path: '$prefix$route',
      queryParameters: query.isEmpty ? null : query,
    );
    try {
      return await (() async {
        final request = http.Request(verb, uri);
        request.followRedirects = false;
        request.headers.addAll({'accept': 'application/json', ...headers});
        if (body != null) {
          request.headers['content-type'] = 'application/json; charset=utf-8';
          request.body = jsonEncode(body);
        }
        final response = await http.Response.fromStream(
          await client.send(request),
        );
        final raw = utf8.decode(response.bodyBytes);
        Map<String, dynamic>? envelope;
        try {
          final value = jsonDecode(raw);
          if (value is Map<String, dynamic>) envelope = value;
        } on FormatException {
          /* Preserve HTTP status below. */
        }
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            envelope?['error'] != null) {
          final error = envelope?['error'];
          throw ApiFailure(
            error is Map
                ? error['message'] as String? ?? '请求失败，请重试'
                : response.statusCode == 401
                ? '登录已失效，请重新登录'
                : '服务器请求失败（HTTP ${response.statusCode}），请稍后重试',
            code: error is Map ? error['code'] as String? : null,
            unauthenticated: response.statusCode == 401,
          );
        }
        if (response.statusCode == 204) return ApiDocument({});
        final data = envelope?['data'];
        if (data is! Map<String, dynamic>) {
          throw const ApiFailure('服务器返回的数据格式无效，请检查接口地址');
        }
        return ApiDocument(
          data,
          nextCursor:
              (envelope?['meta']?['next_cursor'] ?? data['next_cursor'] ?? '')
                  as String,
        );
      })().timeout(
        Duration(
          seconds:
              route == '/me/identity-verification/ocr' ||
                  route.startsWith('/me/identity-verification/face-sessions')
              ? 45
              : 20,
        ),
      );
    } on HandshakeException catch (e) {
      throw ApiFailure('无法建立服务器安全连接，请稍后重试', cause: e);
    } on SocketException catch (e) {
      throw ApiFailure('无法连接服务器，请检查网络后重试', cause: e);
    } on TimeoutException {
      throw const ApiFailure('请求超时，请重试');
    } on HttpException {
      throw const ApiFailure('服务器连接中断，请稍后重试');
    } on http.ClientException catch (e) {
      throw ApiFailure('无法连接服务器，请稍后重试', cause: e);
    } on FormatException {
      throw const ApiFailure('服务器返回的数据格式无效');
    }
  }

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    final route = httpRoutes[method];
    if (route == null) throw const ApiFailure('接口配置无效');
    final url = route.$2.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
      final value = path[match[1]];
      if (value == null) throw const ApiFailure('缺少接口路径参数');
      return Uri.encodeComponent(value);
    });
    return send(route.$1, url, query: query, body: body, headers: headers);
  }

  @override
  Future<CaptchaChallenge> createCaptcha(Map<String, String> headers) async {
    final v = (await send(
      'POST',
      '/auth/captchas',
      query: {'type': 'SLIDE'},
      body: {},
      headers: headers,
    )).data;
    if (v['kind'] != 'SLIDE' ||
        v['id'] is! String ||
        v['master_image_data_url'] is! String ||
        v['thumb_image_data_url'] is! String ||
        v['piece_y'] is! int ||
        v['max_x'] is! int ||
        (v['max_x'] as int) <= 0) {
      throw const ApiFailure('图形验证暂不可用，请稍后重试');
    }
    return CaptchaChallenge(
      id: v['id'] as String,
      masterImageDataUrl: v['master_image_data_url'] as String,
      thumbImageDataUrl: v['thumb_image_data_url'] as String,
      pieceY: v['piece_y'] as int,
      maxX: v['max_x'] as int,
    );
  }

  @override
  Future<auth.CaptchaVerification> verifyCaptcha(
    String id,
    int position,
    Map<String, String> headers,
  ) async {
    final v = (await send(
      'POST',
      '/auth/captchas/${Uri.encodeComponent(id)}/verify',
      body: {'x': position},
      headers: headers,
    )).data;
    return auth.CaptchaVerification(
      captchaToken: v['captcha_token'] as String?,
    );
  }

  @override
  Future<auth.SMSResponse> sendSMS(
    String phone,
    String captchaToken,
    Map<String, String> headers,
  ) async {
    final v = (await send(
      'POST',
      '/auth/sms-codes',
      body: {'phone': phone, 'captcha_token': captchaToken, 'purpose': 'LOGIN'},
      headers: headers,
    )).data;
    return auth.SMSResponse(
      retryAfterSeconds: v['retry_after_seconds'] as int?,
      deliveryStatus: v['delivery_status'] as String?,
    );
  }

  @override
  Future<auth.LoginResponse> login(
    String phone,
    String code,
    Map<String, String> headers,
  ) async {
    final v = (await send(
      'POST',
      '/auth/phone/exchange',
      body: {'phone': phone, 'code': code},
      headers: headers,
    )).data;
    return _loginResponse(v);
  }

  @override
  Future<auth.LoginResponse> loginWithWeChat(
    String code,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  ) async {
    final v = (await send(
      'POST',
      '/auth/wechat/mobile/exchange',
      body: {'code': code, 'agreement_versions': agreementVersions},
      headers: headers,
    )).data;
    return _loginResponse(v);
  }

  @override
  Future<auth.LoginResponse> loginWithDouyin(
    String code,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  ) async {
    final v = (await send(
      'POST',
      '/auth/douyin/mobile/exchange',
      body: {'code': code, 'agreement_versions': agreementVersions},
      headers: headers,
    )).data;
    return _loginResponse(v);
  }

  @override
  Future<auth.LoginResponse> confirmRegistration(
    String registrationToken,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  ) async => _loginResponse(
    (await send(
      'POST',
      '/auth/registrations/confirm',
      body: {
        'registration_token': registrationToken,
        'confirmed': true,
        'agreement_versions': agreementVersions,
      },
      headers: headers,
    )).data,
  );

  @override
  Future<auth.TokenResponse> refresh(
    String token,
    Map<String, String> headers,
  ) async {
    final v = (await send(
      'POST',
      '/auth/token/refresh',
      body: {'refresh_token': token},
      headers: headers,
    )).data;
    return auth.TokenResponse(
      accessToken: v['access_token'] as String?,
      refreshToken: v['refresh_token'] as String?,
    );
  }

  @override
  Future<void> close() async => client.close();
}

auth.LoginResponse _loginResponse(Map<String, dynamic> value) {
  final user = value['user'] as Map?;
  return auth.LoginResponse(
    accessToken: value['access_token'] as String?,
    refreshToken: value['refresh_token'] as String?,
    user: user == null
        ? null
        : auth.UserIdentity(
            id: Int64.parseInt('${user['id'] ?? 0}'),
            publicId: user['public_id'] as String?,
          ),
    registrationRequired: value['registration_required'] as bool?,
    registrationToken: value['registration_token'] as String?,
    registrationExpiresInSeconds:
        value['registration_expires_in_seconds'] as int?,
  );
}

String newDeviceID() => List.generate(
  24,
  (_) => Random.secure().nextInt(256),
).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
