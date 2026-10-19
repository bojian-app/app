import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';

abstract interface class DouyinAuthorizer {
  /// Returns null when authorization is cancelled by the user.
  Future<String?> authorize();
}

class NativeDouyinAuthorizer implements DouyinAuthorizer {
  NativeDouyinAuthorizer({
    MethodChannel? channel,
    this.timeout = const Duration(minutes: 2),
  }) : _channel = channel ?? const MethodChannel('cn.kelance.bojian/douyin');

  static const clientKey = String.fromEnvironment(
    'DOUYIN_CLIENT_KEY',
    defaultValue: 'awll007zjoe179hs',
  );
  static const callbackURL = 'https://bojian.kelance.cn/douyin/';
  final MethodChannel _channel;
  final Duration timeout;
  bool _authorizing = false;

  @override
  Future<String?> authorize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const ApiFailure('当前设备暂不支持抖音登录');
    }
    if (_authorizing) throw const ApiFailure('正在等待抖音授权');
    _authorizing = true;
    final random = Random.secure();
    final state = List.generate(
      24,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('authorize', {
            'clientKey': clientKey,
            'scope': 'user_info',
            'state': state,
            'redirectUri': callbackURL,
          })
          .timeout(timeout);
      if (response == null || response['state'] != state) {
        throw const ApiFailure('抖音授权校验失败，请重试');
      }
      if (response['cancelled'] == true) return null;
      final code = response['code'];
      if (code is! String || code.trim().isEmpty || code.length > 2048) {
        throw const ApiFailure('抖音授权信息无效，请重试');
      }
      return code;
    } on TimeoutException {
      throw const ApiFailure('抖音授权超时，请重试');
    } on MissingPluginException {
      throw const ApiFailure('当前设备暂不支持抖音登录');
    } on PlatformException catch (error) {
      if (error.code == 'CANCELLED') return null;
      if (error.code == 'AUTH_FAILED') {
        final details = error.details;
        final providerCode = details is Map ? details['providerCode'] : null;
        if (providerCode == -2) return null;
        final numericCode = providerCode is int ? providerCode : null;
        final suffix = numericCode == null ? '' : '（$numericCode）';
        throw ApiFailure(
          switch (numericCode) {
            -3 ||
            -12 ||
            -13 ||
            -14 ||
            -15 ||
            -16 ||
            -21 => '抖音授权网络异常，请稍后重试$suffix',
            7 => '操作过于频繁，请稍后重试$suffix',
            10003 ||
            10011 ||
            10012 ||
            10013 ||
            10014 ||
            10015 ||
            10017 => '抖音暂时无法验证此应用，请稍后重试$suffix',
            10004 => '抖音登录权限暂不可用，请稍后重试$suffix',
            _ => '抖音授权失败，请重试$suffix',
          },
          code: numericCode == null
              ? 'DOUYIN_AUTH_FAILED'
              : 'DOUYIN_SDK_$numericCode',
        );
      }
      throw ApiFailure(switch (error.code) {
        'NOT_INSTALLED' => '请先安装抖音后再使用抖音登录',
        'TIMEOUT' => '抖音授权超时，请重试',
        'BUSY' => '正在等待抖音授权',
        'DENIED' => '您未同意抖音授权，请重试',
        'STATE_MISMATCH' => '抖音授权校验失败，请重试',
        _ => '抖音授权失败，请重试',
      });
    } finally {
      // Releasing the native request also discards callbacks arriving after a timeout.
      try {
        await _channel
            .invokeMethod<void>('cancel', {'state': state})
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // A broken cleanup channel must not prevent retrying authorization.
      } on PlatformException {
        // Authorization result remains authoritative if native cleanup fails.
      } on MissingPluginException {
        // Unsupported devices have no pending native request.
      } finally {
        _authorizing = false;
      }
    }
  }
}
