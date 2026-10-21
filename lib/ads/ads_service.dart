import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pangle_ads/pangle_ads.dart';

import 'ads_config.dart';

/// 应用侧的广告调度。
///
/// 两条硬规则：
/// 1. 只有用户已经明确同意《用户协议》《隐私政策》（即已登录）才初始化 SDK；
/// 2. 开屏每次进程只尝试一次，失败静默放过，绝不阻塞启动。
class AdsService {
  AdsService._();

  static bool _initialized = false;
  static bool _initializing = false;
  static bool _splashShown = false;

  /// SDK 是否已经就绪，Banner 之类的组件据此决定是否真的去请求广告。
  static bool get isReady => _initialized;

  static Future<bool> bootstrap() async {
    if (!AdsConfig.enabled || !PangleAds.isSupported) return false;
    if (_initialized) return true;
    if (_initializing) return false;
    _initializing = true;
    try {
      _initialized = await PangleAds.initialize(
        appId: AdsConfig.appId,
        debug: kDebugMode,
      );
      return _initialized;
    } finally {
      _initializing = false;
    }
  }

  /// 冷启动展示一次开屏。
  static Future<void> showSplashOnce() async {
    if (!_initialized || _splashShown) return;
    _splashShown = true;
    await PangleAds.showSplash(
      slotId: AdsConfig.splashSlotId,
      timeoutMs: AdsConfig.splashTimeoutMs,
    );
  }
}
