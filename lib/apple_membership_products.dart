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

  /// 会员加购 AI 次数的消耗型商品：Apple 只能按固定价格档卖，所以是固定次数包。
  static const addonProductIDs = {
    'CREATE_1': 'cn.kelance.bojian.ai.create.1',
    'CREATE_5': 'cn.kelance.bojian.ai.create.5',
    'CREATE_10': 'cn.kelance.bojian.ai.create.10',
    'POLISH_1': 'cn.kelance.bojian.ai.polish.1',
    'POLISH_5': 'cn.kelance.bojian.ai.polish.5',
    'POLISH_10': 'cn.kelance.bojian.ai.polish.10',
    'TEXT_10': 'cn.kelance.bojian.ai.text.10',
    'TEXT_50': 'cn.kelance.bojian.ai.text.50',
    'TEXT_100': 'cn.kelance.bojian.ai.text.100',
  };

  static const allProductIDs = {...productIDs, ...addonProductIDs};

  /// 某类加购的各档（商品键、次数），按次数升序。
  static List<(String, int)> addonPacks(String kind) => [
    for (final key in addonProductIDs.keys)
      if (key.startsWith('${kind}_')) (key, int.parse(key.split('_').last)),
  ];

  /// App Store 当前店面的价格；商品未上架时为 null。
  String? price(String key) => _prices[key];

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
            'productIDs': allProductIDs.values.toList(),
          })
          .timeout(const Duration(seconds: 15));
      if (_disposed) return;
      final products = response?['products'] as List? ?? const [];
      for (final entry in allProductIDs.entries) {
        for (final product in products.whereType<Map>()) {
          final price = product['displayPrice'];
          if (product['id'] == entry.value &&
              price is String &&
              price.isNotEmpty) {
            _prices[entry.key] = price;
          }
        }
      }
      // 加购商品未上架只隐藏加购，不影响开通会员。
      if (!productIDs.keys.every(_prices.containsKey)) {
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
