import 'package:flutter/foundation.dart';

/// Banners may mount after session restoration and the welcome animation.
class BannerAds {
  static final ready = ValueNotifier(false);

  /// 第三方广告已让位给内部广告的登录会话（记录 store.epoch），
  /// 本次运行内同一会话不再重新请求第三方广告。
  static final replacedEpoch = Expando<int>();

  // This is a shared CSJ test application, confirmed in the user's console.
  // Override these with platform-specific IDs before switching to production.
  static const iosAppId = String.fromEnvironment(
    'PANGLE_IOS_APP_ID',
    defaultValue: '5898107',
  );
  static const iosBannerId = String.fromEnvironment(
    'PANGLE_IOS_BANNER_ID',
    defaultValue: '104712824',
  );
  static const iosUseMediation = bool.fromEnvironment(
    'PANGLE_IOS_USE_MEDIATION',
    defaultValue: true,
  );
}
