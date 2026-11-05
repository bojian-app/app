import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';

/// Native eligibility and server-to-server verification are both required.
class RewardedAd {
  static const channel = MethodChannel('cn.kelance.bojian/rewarded-ad');
  static String get platform => defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : '';
  static Future<bool> available(AppStore store) async {
    if (kIsWeb || platform.isEmpty || !store.isAuthenticated) return false;
    final result = await store.request(
      'GetWalletRewardedAd',
      query: {'platform': platform},
    );
    return result.data['enabled'] == true;
  }

  static Future<int> watch(AppStore store) async {
    final epoch = store.epoch;
    final response = await store.request(
      'PostWalletAdSessions',
      body: {'platform': platform},
      extra: {
        'idempotency-key':
            'ad-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      },
    );
    if (epoch != store.epoch) throw const ApiFailure('登录状态已改变');
    final session = response.data;
    final result = await channel.invokeMapMethod<String, dynamic>('show', {
      'appId': session['app_id'],
      'slotId': session['slot_id'],
      'userId': session['user_id'],
      'extra': session['extra'],
      'consent': true,
    });
    if (epoch != store.epoch) throw const ApiFailure('登录状态已改变');
    if (result?['eligible'] != true) return 0;
    // Provider verification may arrive shortly after the native callback.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final claim = await store.request(
          'PostWalletAdSessionsIdClaims',
          path: {'id': '${session['id']}'},
          body: {},
        );
        return claim.data['deduplicated'] == true
            ? 0
            : integer(claim.data['points']);
      } on ApiFailure catch (e) {
        if (e.code != 'AD_NOT_VERIFIED' || attempt == 4) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (epoch != store.epoch) throw const ApiFailure('登录状态已改变');
      }
    }
    return 0;
  }
}
