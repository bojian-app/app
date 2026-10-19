import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluwx_no_pay/fluwx_no_pay.dart';

import 'api/bojian_api.dart';

abstract interface class WeChatAuthorizer {
  /// Returns null when the user cancels authorization.
  Future<String?> authorize();
}

class NativeWeChatAuthorizer implements WeChatAuthorizer {
  NativeWeChatAuthorizer([this._sdk]);

  static const appID = 'wx049616c5bdaf4ff2';
  static const universalLink = 'https://bojian.kelance.cn/wechat/';
  Fluwx? _sdk;
  bool _authorizing = false;

  @override
  Future<String?> authorize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const ApiFailure('当前设备暂不支持微信登录');
    }
    if (_authorizing) throw const ApiFailure('正在等待微信授权');
    _authorizing = true;
    try {
      final sdk = _sdk ??= Fluwx();
      if (!await sdk.registerApi(appId: appID, universalLink: universalLink)) {
        throw const ApiFailure('微信登录暂不可用，请稍后重试');
      }
      if (!await sdk.isWeChatInstalled) {
        throw const ApiFailure('请先安装微信后再使用微信登录');
      }
      final random = Random.secure();
      final state = List.generate(
        24,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final completion = Completer<WeChatAuthResponse?>();
      final subscriber = sdk.addSubscriber((response) {
        if (response is WeChatAuthResponse && !completion.isCompleted) {
          // A callback from an earlier attempt must not finish this request.
          if (response.state?.isNotEmpty == true && response.state != state) {
            return;
          }
          completion.complete(response);
        }
      });
      final returnObserver = _WeChatAuthorizationReturn(() {
        if (!completion.isCompleted) completion.complete(null);
      });
      try {
        final launched = await sdk
            .authBy(
              which: NormalAuth(scope: 'snsapi_userinfo', state: state),
            )
            .timeout(const Duration(seconds: 10));
        if (!launched) throw const ApiFailure('无法打开微信，请稍后重试');
        final response = await completion.future.timeout(
          const Duration(minutes: 2),
        );
        if (response == null || response.errCode == -2) return null;
        if (!response.isSuccessful) {
          throw const ApiFailure('微信授权失败，请重试');
        }
        if (response.state != state || (response.code?.isEmpty ?? true)) {
          throw const ApiFailure('微信授权校验失败，请重试');
        }
        return response.code;
      } finally {
        returnObserver.dispose();
        subscriber.cancel();
      }
    } on TimeoutException {
      throw const ApiFailure('微信授权超时，请重试');
    } on PlatformException {
      throw const ApiFailure('暂时无法打开微信，请稍后重试');
    } on MissingPluginException {
      throw const ApiFailure('当前设备暂不支持微信登录');
    } finally {
      _authorizing = false;
    }
  }
}

/// A cancelled Android app chooser can return focus without backgrounding the
/// app or sending an SDK response. Give queued callbacks time to arrive after
/// focus returns, and stop that grace period if another window takes focus.
class _WeChatAuthorizationReturn with WidgetsBindingObserver {
  _WeChatAuthorizationReturn(this.onReturn)
    : _observeFocusLoss = defaultTargetPlatform == TargetPlatform.android {
    WidgetsBinding.instance.addObserver(this);
  }

  final VoidCallback onReturn;
  final bool _observeFocusLoss;
  bool _interrupted = false;
  Timer? _returnTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _returnTimer?.cancel();
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          (_observeFocusLoss && state == AppLifecycleState.inactive)) {
        _interrupted = true;
      }
    } else if (_interrupted) {
      _returnTimer?.cancel();
      _returnTimer = Timer(const Duration(seconds: 1), onReturn);
    }
  }

  void dispose() {
    _returnTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
