import 'package:flutter/foundation.dart';

/// Banners may mount after session restoration and the welcome animation.
class BannerAds {
  static final ready = ValueNotifier(false);

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
