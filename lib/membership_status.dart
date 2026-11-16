import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_store.dart';

/// 当前登录账号的会员有效期，全应用共用。广告等会员权益读取这一份，
/// 开通、续费、到期都会即时反映。
class MembershipStatus extends ChangeNotifier {
  MembershipStatus._();
  static final instance = MembershipStatus._();

  int _userID = 0;
  int _requestedFor = 0;
  DateTime? _endsAt;
  Timer? _expiry;

  /// 已读取到 [userID] 的会员状态；读取失败或换账号后为 false。
  bool knownFor(int userID) => userID > 0 && userID == _userID;

  bool isMemberOf(int userID) =>
      knownFor(userID) && (_endsAt?.isAfter(DateTime.now()) ?? false);

  /// 写入已确认的会员状态；[endsAt] 为空表示不是会员。
  void apply(int userID, DateTime? endsAt) {
    _userID = userID;
    _requestedFor = userID;
    _endsAt = endsAt;
    _expiry?.cancel();
    if (endsAt != null && endsAt.isAfter(DateTime.now())) {
      _expiry = Timer(endsAt.difference(DateTime.now()), notifyListeners);
    }
    notifyListeners();
  }

  void reset() {
    if (_userID == 0 && _requestedFor == 0) return;
    _expiry?.cancel();
    _userID = 0;
    _requestedFor = 0;
    _endsAt = null;
    notifyListeners();
  }

  /// 登录或切换账号后读取一次；[force] 用于回到前台时刷新。
  Future<void> refresh(AppStore store, {bool force = false}) async {
    final userID = store.userID;
    if (!store.isAuthenticated || userID <= 0) {
      reset();
      return;
    }
    if (!force && _requestedFor == userID) return;
    _requestedFor = userID;
    final epoch = store.epoch;
    try {
      final result = await store.request('GetMembership');
      if (store.epoch != epoch || store.userID != userID) return;
      final value = result.data['ends_at'];
      final ends = value is String ? DateTime.tryParse(value)?.toLocal() : null;
      apply(userID, result.data['active'] == true ? ends : null);
    } catch (_) {
      // 读取失败保留上次结果；回到前台时会再试。
    }
  }
}
