import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get usesAppleMembership => defaultTargetPlatform == TargetPlatform.iOS;

/// Prices come from the customer's App Store storefront, not the Android catalog.
class AppleMembershipProducts extends ChangeNotifier {
  static const channel = MethodChannel('cn.kelance.bojian/apple_products');

  /// One-time memberships keep the original non-renewing IDs; the auto-renew
  /// choice buys the ".auto" products. Keys match the server.
  static const productIDs = {
    'MONTH': 'cn.kelance.bojian.membership.month',
    'YEAR': 'cn.kelance.bojian.membership.year',
    'MONTH_AUTO': 'cn.kelance.bojian.membership.month.auto',
    'YEAR_AUTO': 'cn.kelance.bojian.membership.year.auto',
  };

  static String productKey(String planCode, {bool autoRenew = false}) =>
      autoRenew ? '${planCode}_AUTO' : planCode;

  final Map<String, String> _prices = {};
  bool loading = false;
  String? error;
  bool _disposed = false;

  String priceLabel(String planCode, {bool autoRenew = false}) =>
      _prices[productKey(planCode, autoRenew: autoRenew)] ??
      (loading ? '加载中…' : '暂不可用');

  bool available(String planCode, {bool autoRenew = false}) =>
      _prices.containsKey(productKey(planCode, autoRenew: autoRenew));

  /// Opens the App Store sheet where auto-renewal is turned off.
  static Future<void> manageSubscriptions() =>
      channel.invokeMethod<void>('manageSubscriptions');

  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    error = null;
    _prices.clear();
    notifyListeners();
    try {
      final response = await channel
          .invokeMapMethod<String, dynamic>('products', {
            'productIDs': productIDs.values.toList(),
          })
          .timeout(const Duration(seconds: 15));
      if (_disposed) return;
      final products = response?['products'] as List? ?? const [];
      for (final entry in productIDs.entries) {
        for (final product in products.whereType<Map>()) {
          final price = product['displayPrice'];
          if (product['id'] == entry.value &&
              price is String &&
              price.isNotEmpty) {
            _prices[entry.key] = price;
          }
        }
      }
      if (_prices.length < productIDs.length) {
        error = '部分套餐暂不可用，请稍后刷新。';
      }
    } on PlatformException {
      error = '暂时无法获取 App Store 商品，请稍后重试。';
    } on MissingPluginException {
      error = '当前设备暂不支持 App Store 内购。';
    } on TimeoutException {
      error = '连接 App Store 超时，请稍后重试。';
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
