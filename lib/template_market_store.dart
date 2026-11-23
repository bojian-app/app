import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'apple_membership_products.dart';
import 'apple_membership_purchases.dart';
import 'template_preview_cache.dart';

enum TemplateMarketFilter {
  all('全部', ''),
  free('免费', 'FREE'),
  paid('付费', 'PAID'),
  owned('我的', '');

  const TemplateMarketFilter(this.label, this.pricing);
  final String label, pricing;
}

class TemplateMarketStore extends ChangeNotifier {
  TemplateMarketStore(this.store) : epoch = store.epoch {
    store.addListener(accountChanged);
    if (usesAppleMembership) {
      appleProducts = AppleMembershipProducts()..addListener(_appleChanged);
      applePurchases = AppleMembershipPurchases.forStore(store);
      _templateRevision = applePurchases!.templateRevision;
      applePurchases!.addListener(_appleChanged);
    }
  }
  final AppStore store;
  final int epoch;
  AppleMembershipProducts? appleProducts;
  AppleMembershipPurchases? applePurchases;
  int _templateRevision = 0;
  bool get appleBusy => applePurchases?.busy == true;

  void _appleChanged() {
    if (!valid) return;
    if (_templateRevision != applePurchases!.templateRevision) {
      _templateRevision = applePurchases!.templateRevision;
      unawaited(loadOwned());
    }
    notifyListeners();
  }

  /// Android charges the per-template price set in the admin console; iOS
  /// shows the App Store price of the template's own product.
  String priceLabel(int id, int priceCents) => appleProducts == null
      ? '¥${(priceCents / 100).toStringAsFixed(2)}'
      : appleProducts!.templatePrice(id) ??
            (appleProducts!.loading ? '价格加载中…' : '暂不可购买');

  bool canPurchase(int id) =>
      appleProducts == null ||
      (!appleBusy &&
          !applePurchases!.awaitingTemplateApproval(id) &&
          (appleProducts!.templatePrice(id) != null ||
              applePurchases!.needsRetry ||
              applePurchases!.needsRestore));

  String purchaseLabel(int id, int priceCents, {bool includePrice = true}) {
    final label = includePrice ? '${priceLabel(id, priceCents)} 购买' : '立即购买';
    final purchases = applePurchases;
    if (purchases == null) return label;
    if (purchases.busy) return '正在处理…';
    if (purchases.needsRetry) return '重试确认';
    if (purchases.needsRestore) return '恢复并确认购买';
    if (purchases.awaitingTemplateApproval(id)) return '等待批准';
    return appleProducts!.templatePrice(id) == null
        ? priceLabel(id, priceCents)
        : label;
  }

  bool alive = true, loading = false, loadingMore = false, loadingOwned = false;
  String query = '', cursor = '';
  String? error, ownedError;
  TemplateMarketFilter filter = TemplateMarketFilter.all;
  List<Map<String, dynamic>> templates = [], owned = [];
  int generation = 0;
  Timer? debounce;
  bool get valid => alive && store.alive && store.epoch == epoch;
  Set<int> get ownedIDs => owned.map((row) => integer(row['id'])).toSet();
  List<Map<String, dynamic>> get visible => filter == TemplateMarketFilter.owned
      ? owned
            .where(
              (row) => '${row['name'] ?? ''}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList()
      : templates;

  void accountChanged() {
    if (alive && store.epoch != epoch) {
      generation++;
      debounce?.cancel();
      templates = [];
      owned = [];
      cursor = '';
      loading = false;
      loadingOwned = false;
      loadingMore = false;
      error = '登录状态已变化，请返回后重试';
      ownedError = error;
      notifyListeners();
    }
  }

  void search(String value, {bool immediately = false}) {
    query = value.trim();
    debounce?.cancel();
    generation++;
    cursor = '';
    templates = [];
    error = null;
    notifyListeners();
    if (filter == TemplateMarketFilter.owned) return;
    if (immediately) {
      unawaited(load());
    } else {
      debounce = Timer(const Duration(milliseconds: 300), load);
    }
  }

  void select(TemplateMarketFilter value) {
    if (value == filter) return;
    filter = value;
    debounce?.cancel();
    generation++;
    cursor = '';
    templates = [];
    error = null;
    loading = false;
    loadingMore = false;
    notifyListeners();
    if (value == TemplateMarketFilter.owned) {
      unawaited(loadOwned());
    } else {
      unawaited(load());
    }
  }

  Future<void> refresh() async {
    debounce?.cancel();
    await Future.wait([
      if (filter != TemplateMarketFilter.owned) load(),
      loadOwned(),
    ]);
  }

  Future<void> load({bool more = false}) async {
    if (!valid ||
        filter == TemplateMarketFilter.owned ||
        (more && (loading || loadingMore || cursor.isEmpty))) {
      return;
    }
    final version = more ? generation : ++generation;
    final querySnapshot = query, pricing = filter.pricing;
    if (more) {
      loadingMore = true;
    } else {
      loading = true;
      loadingMore = false;
      templates = [];
      cursor = '';
    }
    error = null;
    notifyListeners();
    try {
      final result = await store.request(
        'GetTemplates',
        query: {
          'limit': '24',
          if (querySnapshot.isNotEmpty) 'query': querySnapshot,
          if (pricing.isNotEmpty) 'pricing': pricing,
          if (more) 'cursor': cursor,
        },
      );
      if (!valid || version != generation) return;
      final seen = <int>{};
      templates = [if (more) ...templates, ...items(result.data)]
          .where(
            (row) => integer(row['id']) > 0 && seen.add(integer(row['id'])),
          )
          .toList();
      cursor = result.nextCursor;
    } catch (e) {
      if (valid && version == generation) {
        error = e is ApiFailure ? e.message : '模板加载失败，请重试';
      }
    } finally {
      if (valid && version == generation) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  int ownershipGeneration = 0;
  Future<void> loadOwned() async {
    if (!valid) return;
    final version = ++ownershipGeneration;
    loadingOwned = true;
    ownedError = null;
    notifyListeners();
    try {
      final result = await store.request('GetMeTemplates');
      if (!valid || version != ownershipGeneration) return;
      final seen = <int>{};
      owned = items(result.data)
          .where(
            (row) =>
                row['source'] == 'ACQUIRED' &&
                // Paid templates count as owned only once bought for good; an
                // old membership-period acquisition expires with the membership.
                (row['pricing_type'] != 'PAID' || row['expires_at'] == null) &&
                integer(row['id']) > 0 &&
                seen.add(integer(row['id'])),
          )
          .toList();
    } catch (e) {
      if (valid && version == ownershipGeneration) {
        ownedError = e is ApiFailure ? e.message : '购买记录加载失败';
      }
    } finally {
      if (valid && version == ownershipGeneration) {
        loadingOwned = false;
        notifyListeners();
      }
    }
  }

  Future<void> acquire({required int id, required int quotedRevision}) async {
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    await loadOwned();
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    if (ownedError != null) throw ApiFailure(ownedError!);
    if (ownedIDs.contains(id)) {
      final template = owned.firstWhere((row) => integer(row['id']) == id);
      unawaited(
        predownloadAcquiredTemplate(store, id, integer(template['version'])),
      );
      return;
    }
    final detail = await store.request('GetTemplatesId', path: {'id': '$id'});
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    if (integer(detail.data['revision']) != quotedRevision) {
      throw const ApiFailure('模板信息已更新，请刷新详情后重试');
    }
    if (detail.data['compatible'] != true ||
        detail.data['status'] != 'PUBLISHED') {
      throw const ApiFailure('模板暂不可用');
    }
    await store.request(
      'PostTemplatesIdAcquisitions',
      path: {'id': '$id'},
      body: {},
    );
    if (!valid) return;
    unawaited(
      predownloadAcquiredTemplate(store, id, integer(detail.data['version'])),
    );
    await loadOwned();
  }

  static const _alipay = MethodChannel('cn.kelance.bojian/alipay');
  String? _purchaseKey;

  /// Buys a paid template for good (members pay too). Returns whether it is
  /// now owned; the server confirms payment, never the payment SDK result.
  Future<bool> purchase({required int id}) async {
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    final purchases = applePurchases;
    if (purchases != null) {
      if (purchases.busy) return false;
      await loadOwned();
      if (!valid) throw const ApiFailure('登录状态已变化，请重试');
      if (ownedError != null) throw ApiFailure(ownedError!);
      if (ownedIDs.contains(id)) return true;
      if (purchases.needsRetry) {
        await purchases.retryConfirmation();
      } else if (purchases.needsRestore) {
        await purchases.restore();
      } else {
        if (appleProducts!.templatePrice(id) == null) {
          throw const ApiFailure('App Store 商品暂不可用，请刷新后重试');
        }
        await purchases.purchaseTemplate(id);
      }
      if (!valid) throw const ApiFailure('登录状态已变化，请重试');
      await loadOwned();
      if (!valid) throw const ApiFailure('登录状态已变化，请重试');
      if (ownedError != null) throw ApiFailure(ownedError!);
      if (ownedIDs.contains(id)) return true;
      if (purchases.state == ApplePurchaseState.cancelled) return false;
      throw ApiFailure(purchases.message ?? '该模板尚未确认购买，请恢复购买后重试');
    }
    _purchaseKey ??=
        'mobile-template-$id-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    try {
      final order = await store.request(
        'PostTemplateOrders',
        body: {'template_id': id, 'channel': 'ALIPAY'},
        extra: {'idempotency-key': _purchaseKey!},
      );
      var data = order.data;
      if (data['status'] != 'PAID') {
        final orderString = data['alipay_order_string'];
        if (orderString is! String || orderString.isEmpty) {
          throw const ApiFailure('支付宝暂未开放，请稍后再试');
        }
        final outcome = await _alipay.invokeMapMethod<String, String>('pay', {
          'orderString': orderString,
        });
        if (outcome?['resultStatus'] == '6001') return false;
        final orderID = integer(data['id']);
        for (var i = 0; i < 8 && valid && orderID > 0; i++) {
          try {
            data = (await store.request(
              'GetTemplateOrdersId',
              path: {'id': '$orderID'},
            )).data;
            if (data['status'] == 'PAID') break;
          } on ApiFailure {
            // Keep waiting through a transient network failure.
          }
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
      }
      if (data['status'] != 'PAID') {
        throw const ApiFailure('支付结果确认中，稍后在“我的”中查看');
      }
      _purchaseKey = null;
      await loadOwned();
      return true;
    } on PlatformException catch (e) {
      throw ApiFailure(e.message ?? '无法打开支付宝，请重试');
    } on ApiFailure catch (e) {
      if (e.code == 'TEMPLATE_ORDER_EXPIRED' ||
          e.code == 'IDEMPOTENCY_CONFLICT') {
        _purchaseKey = null;
      }
      rethrow;
    }
  }

  Future<void> restoreApplePurchases() async {
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    final purchases = applePurchases;
    if (purchases == null || purchases.busy) return;
    await purchases.restore();
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    await loadOwned();
    if (!valid) throw const ApiFailure('登录状态已变化，请重试');
    if (ownedError != null) throw ApiFailure(ownedError!);
    if (purchases.state == ApplePurchaseState.error) {
      throw ApiFailure(purchases.message ?? '恢复购买失败，请稍后重试');
    }
  }

  @override
  void dispose() {
    alive = false;
    generation++;
    debounce?.cancel();
    store.removeListener(accountChanged);
    applePurchases?.removeListener(_appleChanged);
    appleProducts?.removeListener(_appleChanged);
    appleProducts?.dispose();
    super.dispose();
  }
}
