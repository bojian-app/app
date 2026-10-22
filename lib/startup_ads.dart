import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Only the cold-start coordinator calls this, after restoring an authenticated
/// session. Login requires accepting the app's agreement and privacy policy.
class StartupAds {
  static const _channel = MethodChannel('cn.kelance.bojian/startup_ads');
  static const _appId = String.fromEnvironment(
    'PANGLE_ANDROID_APP_ID',
    defaultValue: '5898107',
  );
  static const _slotId = String.fromEnvironment(
    'PANGLE_ANDROID_SPLASH_ID',
    defaultValue: '104711277',
  );
  static bool _attempted = false;
  static final readyForBanner = ValueNotifier(false);

  static Future<void> showOnce() async {
    if (!Platform.isAndroid || _attempted) return;
    _attempted = true;
    try {
      final status = await _channel
          .invokeMethod<String>('showSplash', {
            'appId': _appId,
            'slotId': _slotId,
            'consent': true,
          })
          .timeout(const Duration(seconds: 20));
      debugPrint('StartupAds: $status');
    } on TimeoutException {
      await cancel();
    } on PlatformException catch (error) {
      debugPrint('StartupAds: ${error.code}');
    } on MissingPluginException {
      // iOS/desktop and widget hosts do not load the Android bridge.
    }
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel
          .invokeMethod<void>('cancel')
          .timeout(const Duration(seconds: 1));
    } on PlatformException {
      // Leaving startup must not block navigation.
    } on MissingPluginException {
      // No native bridge in a widget host.
    } on TimeoutException {
      // The native bridge also has its own deadline.
    }
  }
}
