import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'apple_membership_products.dart';

enum ApplePurchaseState {
  idle,
  preparing,
  purchasing,
  pending,
  confirming,
  delivered,
  cancelled,
  restoring,
  error,
}

/// Owns the transaction listener for the whole signed-in application, including
/// transactions that complete after the checkout page has gone away.
class AppleMembershipPurchases extends ChangeNotifier {
  AppleMembershipPurchases(this.store);

  static final _instances = Expando<AppleMembershipPurchases>();
  static AppleMembershipPurchases forStore(AppStore store) =>
      _instances[store] ??= (AppleMembershipPurchases(store)..start());

  final AppStore store;
  final _inFlight = <String, Future<bool>>{};
  final _unconfirmed = <String, Map<String, dynamic>>{};
  final _pendingApprovals = <String>{};
  final _uncertainPurchases = <String>{};
  bool _started = false;
  bool _disposed = false;
  bool _userOperation = false;
  Future<void>? _syncing;
  int _epoch = -1;
  int _userID = 0;
  String? _accountToken;
  Set<String> _accountTokens = {};
  ApplePurchaseState state = ApplePurchaseState.idle;
  String? message;
  String? lastDeliveredProductID;
  int membershipRevision = 0;

  bool get busy => _userOperation || _inFlight.isNotEmpty;
  bool get needsRetry => _unconfirmed.isNotEmpty;
  bool get needsRestore => _uncertainPurchases.isNotEmpty;
  bool awaitingApproval(String planCode, {bool autoRenew = false}) =>
      _pendingApprovals.contains(
        AppleMembershipProducts.productIDs[AppleMembershipProducts.productKey(
          planCode,
          autoRenew: autoRenew,
        )],
      );

  void start() {
    if (_started || _disposed) return;
    _started = true;
    AppleMembershipProducts.channel.setMethodCallHandler(_nativeEvent);
    store.addListener(_sessionChanged);
    _sessionChanged();
  }

  void _sessionChanged() {
    if (_epoch == store.epoch && _userID == store.userID) return;
    _epoch = store.epoch;
    _userID = store.userID;
    _accountToken = null;
    _accountTokens = {};
    _unconfirmed.clear();
    _pendingApprovals.clear();
    _uncertainPurchases.clear();
    state = ApplePurchaseState.idle;
    message = null;
    lastDeliveredProductID = null;
    _notify();
    if (store.isAuthenticated) {
      final previousSync = _syncing;
      if (previousSync == null) {
        unawaited(syncUnfinished());
      } else {
        unawaited(previousSync.then((_) => syncUnfinished()));
      }
    }
  }

  bool _current(int epoch, int userID) =>
      !_disposed &&
      store.alive &&
      store.isAuthenticated &&
      store.epoch == epoch &&
      store.userID == userID;

  void _requireCurrent(int epoch, int userID) {
    if (!_current(epoch, userID)) {
      throw const ApiFailure('账号已切换，请重新进入会员页面');
    }
  }

  Future<Map<String, dynamic>> _configuration(int epoch, int userID) async {
    _requireCurrent(epoch, userID);
    final result = await store.request(
      'GetMembershipApple',
      expectedEpoch: epoch,
    );
    _requireCurrent(epoch, userID);
    final token = result.data['app_account_token'];
    if (token is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(token)) {
      throw const ApiFailure('Apple 内购配置暂不可用，请稍后重试');
    }
    _accountToken = token.toLowerCase();
    _accountTokens = {
      _accountToken!,
      ...((result.data['app_account_tokens'] as List?) ?? const [])
          .whereType<String>()
          .map((value) => value.toLowerCase()),
    };
    return result.data;
  }

  Future<void> _nativeEvent(MethodCall call) async {
    if (_disposed || !store.isAuthenticated) return;
    if (call.method == 'transaction') {
      final epoch = store.epoch;
      final userID = store.userID;
      try {
        if (_accountToken == null) await _configuration(epoch, userID);
        _requireCurrent(epoch, userID);
        final transaction = _transaction(call.arguments);
        if (transaction != null && _belongsToAccount(transaction)) {
          await _deliver(transaction, epoch, userID);
        }
      } catch (error) {
        if (_current(epoch, userID)) _error(error);
      }
    } else if (call.method == 'transactionError') {
      _error(const ApiFailure('Apple 交易验证未通过，请稍后恢复购买重试'));
    }
  }

  Map<String, dynamic>? _transaction(Object? value) {
    if (value is! Map) return null;
    final transaction = Map<String, dynamic>.from(value);
    if (transaction['transactionID'] is! String ||
        !RegExp(r'^\d+$').hasMatch(transaction['transactionID'] as String) ||
        !const ['Production', 'Sandbox'].contains(transaction['environment']) ||
        !AppleMembershipProducts.allProductIDs.values.contains(
          transaction['productID'],
        )) {
      return null;
    }
    return transaction;
  }

  bool _belongsToAccount(Map<String, dynamic> transaction) =>
      transaction['appAccountToken'] is String &&
      _accountTokens.contains(
        (transaction['appAccountToken'] as String).toLowerCase(),
      );

  String _key(Map<String, dynamic> transaction) =>
      '${transaction['environment']}:${transaction['transactionID']}';

  Future<List<Map<String, dynamic>>> _transactions(String method) async {
    final result = await AppleMembershipProducts.channel
        .invokeMapMethod<String, dynamic>(method);
    if (result?['unverified'] == true) {
      throw const ApiFailure('部分 Apple 交易验证未通过，请稍后恢复购买重试');
    }
    return (result?['transactions'] as List? ?? const [])
        .map(_transaction)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// This never prompts for an Apple login. Explicit restore is separate below.
  Future<void> syncUnfinished() {
    if (_disposed || !store.isAuthenticated) return Future.value();
    return _syncing ??= _syncUnfinished().whenComplete(() => _syncing = null);
  }

  Future<void> _syncUnfinished() async {
    final epoch = store.epoch;
    final userID = store.userID;
    try {
      final transactions = await _transactions('unfinished');
      _requireCurrent(epoch, userID);
      if (transactions.isEmpty) return;
      await _configuration(epoch, userID);
      for (final transaction in transactions) {
        _requireCurrent(epoch, userID);
        if (_belongsToAccount(transaction)) {
          await _deliver(transaction, epoch, userID);
        }
      }
    } catch (error) {
      if (_current(epoch, userID)) _error(error);
    }
  }

  Future<bool> _deliver(
    Map<String, dynamic> transaction,
    int epoch,
    int userID,
  ) {
    if (!_current(epoch, userID) || !_belongsToAccount(transaction)) {
      return Future.value(false);
    }
    final key = _key(transaction);
    final operationKey = '$epoch:$userID:$key';
    final existing = _inFlight[operationKey];
    if (existing != null) return existing;
    final future = _deliverOnce(transaction, epoch, userID).whenComplete(() {
      _inFlight.remove(operationKey);
      _notify();
    });
    _inFlight[operationKey] = future;
    return future;
  }

  Future<bool> _deliverOnce(
    Map<String, dynamic> transaction,
    int epoch,
    int userID,
  ) async {
    final key = _key(transaction);
    _unconfirmed[key] = transaction;
    _set(ApplePurchaseState.confirming, '正在确认订单与会员权益…');
    try {
      _requireCurrent(epoch, userID);
      final result = await store.request(
        'PostMembershipAppleTransactions',
        expectedEpoch: epoch,
        body: {
          'transaction_id': transaction['transactionID'],
          'environment': transaction['environment'],
        },
      );
      _requireCurrent(epoch, userID);
      final status = result.data['status'];
      if (result.data['transaction_id'] != transaction['transactionID'] ||
          !const ['DELIVERED', 'EXPIRED', 'REVOKED'].contains(status)) {
        throw const ApiFailure('订单尚未确认，请稍后重试确认');
      }
      // A verified StoreKit transaction alone never grants membership. Only the
      // authenticated server acknowledgement allows the native queue to finish.
      await AppleMembershipProducts.channel.invokeMethod<void>('finish', {
        'transactionID': transaction['transactionID'],
        'environment': transaction['environment'],
        'appAccountToken': transaction['appAccountToken'],
      });
      _requireCurrent(epoch, userID);
      _unconfirmed.remove(key);
      _pendingApprovals.remove(transaction['productID']);
      _uncertainPurchases.remove(transaction['productID']);
      membershipRevision++;
      if (status == 'DELIVERED') {
        lastDeliveredProductID = transaction['productID'] as String;
        _set(ApplePurchaseState.delivered, null);
      } else {
        _set(
          ApplePurchaseState.idle,
          status == 'EXPIRED' ? '历史购买已核对，该笔会员已到期' : '该笔购买已退款或撤销，会员状态已更新',
        );
      }
      return true;
    } catch (error) {
      if (_current(epoch, userID)) {
        _error(error, prefix: '订单尚未完成确认，可重试确认或恢复购买。');
      }
      return false;
    }
  }

  Future<void> purchase(String planCode, {bool autoRenew = false}) => _purchase(
    AppleMembershipProducts.productKey(planCode, autoRenew: autoRenew),
  );

  /// 购买一档加购 AI 次数（消耗型商品），key 见 addonProductIDs。
  Future<void> purchaseAddon(String key) => _purchase(key);

  Future<void> _purchase(String key) async {
    if (busy || _disposed) return;
    final epoch = store.epoch;
    final userID = store.userID;
    _userOperation = true;
    _set(ApplePurchaseState.preparing, '正在准备 App Store 订单…');
    try {
      final config = await _configuration(epoch, userID);
      final productID = AppleMembershipProducts.allProductIDs[key];
      final mapping = config['product_ids'];
      final addons = config['ai_addon_products'];
      final listed =
          (mapping is Map && mapping[key] == productID) ||
          (addons is List &&
              addons.any(
                (product) =>
                    product is Map && product['product_id'] == productID,
              ));
      if (config['available'] != true || productID == null || !listed) {
        throw const ApiFailure('Apple 内购暂不可用，请稍后刷新重试');
      }
      if (_pendingApprovals.contains(productID)) {
        _set(ApplePurchaseState.pending, '购买正在等待批准，批准后会自动确认会员权益');
        return;
      }
      // Before any new charge, retry purchases left unfinished after a network
      // failure. A retry of an existing order must not open another purchase.
      final transactions = await _transactions('unfinished');
      _requireCurrent(epoch, userID);
      final retry = <String, Map<String, dynamic>>{
        ..._unconfirmed,
        for (final transaction in transactions)
          if (_belongsToAccount(transaction)) _key(transaction): transaction,
      };
      var hadOrder = false;
      for (final transaction in retry.values) {
        if (transaction['productID'] == productID) {
          hadOrder = true;
          await _deliver(transaction, epoch, userID);
        }
      }
      if (hadOrder) return;
      if (_uncertainPurchases.contains(productID)) {
        throw const ApiFailure('上次购买状态待确认，请先恢复购买');
      }
      _requireCurrent(epoch, userID);
      _set(ApplePurchaseState.purchasing, '请在 App Store 确认付款');
      _uncertainPurchases.add(productID);
      final response = await AppleMembershipProducts.channel
          .invokeMapMethod<String, dynamic>('purchase', {
            'productID': productID,
            'appAccountToken': _accountToken,
          });
      _requireCurrent(epoch, userID);
      switch (response?['status']) {
        case 'cancelled':
          _uncertainPurchases.remove(productID);
          _set(ApplePurchaseState.cancelled, '已取消购买');
        case 'pending':
          _uncertainPurchases.remove(productID);
          _pendingApprovals.add(productID);
          _set(ApplePurchaseState.pending, '购买正在等待批准，批准后会自动确认会员权益');
        case 'verified':
          final transaction = _transaction(response?['transaction']);
          if (transaction == null || !_belongsToAccount(transaction)) {
            throw const ApiFailure('交易账号信息不匹配，请恢复购买重试');
          }
          await _deliver(transaction, epoch, userID);
        default:
          throw const ApiFailure('Apple 交易验证未通过，请恢复购买重试');
      }
    } catch (error) {
      if (_current(epoch, userID)) _error(error);
    } finally {
      _userOperation = false;
      _notify();
    }
  }

  Future<void> retryConfirmation() async {
    if (busy || _disposed) return;
    _userOperation = true;
    final epoch = store.epoch;
    final userID = store.userID;
    try {
      await _configuration(epoch, userID);
      final retry = <String, Map<String, dynamic>>{
        ..._unconfirmed,
        for (final transaction in await _transactions('unfinished'))
          if (_belongsToAccount(transaction)) _key(transaction): transaction,
      };
      for (final transaction in retry.values) {
        _requireCurrent(epoch, userID);
        await _deliver(transaction, epoch, userID);
      }
    } catch (error) {
      if (_current(epoch, userID)) _error(error);
    } finally {
      _userOperation = false;
      _notify();
    }
  }

  /// Called only by a restore button. Non-renewing history and every
  /// auto-renewal need all transactions, not just currentEntitlements.
  Future<void> restore() async {
    if (busy || _disposed) return;
    final epoch = store.epoch;
    final userID = store.userID;
    _userOperation = true;
    _set(ApplePurchaseState.restoring, '正在恢复并核对历史购买…');
    try {
      await _configuration(epoch, userID);
      final transactions = await _transactions('restore');
      _requireCurrent(epoch, userID);
      var matching = 0;
      var failures = 0;
      for (final transaction in transactions) {
        _requireCurrent(epoch, userID);
        if (!_belongsToAccount(transaction)) continue;
        matching++;
        if (!await _deliver(transaction, epoch, userID)) failures++;
      }
      _requireCurrent(epoch, userID);
      membershipRevision++;
      if (failures > 0) {
        _set(ApplePurchaseState.error, '部分订单尚未确认，请稍后重试确认');
      } else {
        _uncertainPurchases.clear();
        _set(
          ApplePurchaseState.idle,
          matching > 0 ? null : '未找到属于当前博简账号的购买，请确认 Apple 账户与博简账号',
        );
      }
    } catch (error) {
      if (_current(epoch, userID)) _error(error);
    } finally {
      _userOperation = false;
      _notify();
    }
  }

  void _error(Object error, {String prefix = ''}) {
    final detail = switch (error) {
      ApiFailure() => error.message,
      PlatformException() => error.message ?? 'App Store 暂不可用，请稍后重试',
      MissingPluginException() => '当前设备暂不支持 App Store 内购',
      _ => '暂时无法连接，请稍后重试',
    };
    _set(ApplePurchaseState.error, '$prefix$detail');
  }

  void _set(ApplePurchaseState value, String? text) {
    state = value;
    message = text;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      store.removeListener(_sessionChanged);
      AppleMembershipProducts.channel.setMethodCallHandler(null);
    }
    _instances[store] = null;
    super.dispose();
  }
}
