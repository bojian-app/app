import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/bojian_api.dart';
import 'app_qr_login_service.dart';

enum AppQRLoginPhase {
  scanning,
  loading,
  confirmation,
  confirming,
  canceling,
  success,
  canceled,
  expired,
  error,
  sessionChanged,
}

class AppQRLoginController extends ChangeNotifier {
  AppQRLoginController(this.service) {
    service.store.addListener(_accountChanged);
  }
  final AppQRLoginService service;
  AppQRLoginPhase phase = AppQRLoginPhase.scanning;
  AppQRLoginSession? session;
  AppQRLoginCode? _code;
  String? error;
  bool _disposed = false;
  Timer? _timer;
  bool get busy =>
      phase == AppQRLoginPhase.loading ||
      phase == AppQRLoginPhase.confirming ||
      phase == AppQRLoginPhase.canceling;
  bool get expired =>
      session != null && !session!.expiresAt.isAfter(DateTime.now());
  bool get canConfirm =>
      !_disposed &&
      service.isCurrent &&
      phase == AppQRLoginPhase.confirmation &&
      !expired;

  AppQRLoginPhase _failurePhase(Object failure) {
    if (expired || failure is ApiFailure && failure.code == 'APP_QR_EXPIRED') {
      return AppQRLoginPhase.expired;
    }
    if (failure is ApiFailure &&
        const {
          'APP_QR_NOT_FOUND',
          'APP_QR_CLAIMED',
          'APP_QR_STATE_INVALID',
          'APP_QR_SOURCE_INVALID',
          'APP_QR_MOBILE_REQUIRED',
        }.contains(failure.code)) {
      return AppQRLoginPhase.error;
    }
    return AppQRLoginPhase.confirmation;
  }

  void _accountChanged() {
    if (_disposed ||
        service.isCurrent ||
        phase == AppQRLoginPhase.sessionChanged) {
      return;
    }
    _timer?.cancel();
    session = null;
    _code = null;
    phase = AppQRLoginPhase.sessionChanged;
    error = '登录状态已变化，请重新登录后扫码';
    notifyListeners();
  }

  Future<void> scan(String raw) async {
    if (_disposed || phase != AppQRLoginPhase.scanning || !service.isCurrent) {
      return;
    }
    try {
      _code = AppQRLoginCode.parse(raw);
    } on ApiFailure catch (e) {
      error = e.message;
      phase = AppQRLoginPhase.error;
      notifyListeners();
      return;
    }
    phase = AppQRLoginPhase.loading;
    error = null;
    notifyListeners();
    final code = _code!;
    try {
      final result = await service.action(code, 'scan');
      if (_disposed) {
        unawaited(_cancelQuietly(code));
        return;
      }
      if (!service.isCurrent) return;
      session = result;
      phase = result.status == AppQRLoginStatus.confirmed
          ? AppQRLoginPhase.success
          : expired
          ? AppQRLoginPhase.expired
          : AppQRLoginPhase.confirmation;
      if (phase == AppQRLoginPhase.confirmation) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_disposed ||
              !expired ||
              busy ||
              phase != AppQRLoginPhase.confirmation) {
            return;
          }
          phase = AppQRLoginPhase.expired;
          _timer?.cancel();
          notifyListeners();
        });
      }
    } catch (e) {
      if (_disposed || !service.isCurrent) return;
      error = '$e';
      phase = e is ApiFailure && e.code == 'APP_QR_EXPIRED'
          ? AppQRLoginPhase.expired
          : AppQRLoginPhase.error;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> confirm() async {
    if (!canConfirm) return;
    phase = AppQRLoginPhase.confirming;
    error = null;
    notifyListeners();
    try {
      final result = await service.action(_code!, 'confirm');
      if (_disposed || !service.isCurrent) return;
      if (result.status != AppQRLoginStatus.confirmed) {
        throw const ApiFailure('官网登录尚未确认，请重试');
      }
      session = result;
      phase = AppQRLoginPhase.success;
      _timer?.cancel();
    } catch (e) {
      if (_disposed || !service.isCurrent) return;
      error = '$e';
      phase = _failurePhase(e);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> cancel() async {
    if (_disposed || busy || _code == null || !service.isCurrent) return;
    phase = AppQRLoginPhase.canceling;
    error = null;
    notifyListeners();
    try {
      final result = await service.action(_code!, 'cancel');
      if (_disposed || !service.isCurrent) return;
      if (result.status != AppQRLoginStatus.canceled) {
        throw const ApiFailure('未能取消，请重试');
      }
      phase = AppQRLoginPhase.canceled;
      _timer?.cancel();
    } catch (e) {
      if (_disposed || !service.isCurrent) return;
      error = '$e';
      phase = _failurePhase(e);
    }
    if (!_disposed) notifyListeners();
  }

  void rescan() {
    if (_disposed || busy || !service.isCurrent) return;
    final old = _code;
    if (old != null && phase != AppQRLoginPhase.success) {
      unawaited(_cancelQuietly(old));
    }
    _timer?.cancel();
    session = null;
    _code = null;
    error = null;
    phase = AppQRLoginPhase.scanning;
    notifyListeners();
  }

  Future<void> _cancelQuietly(AppQRLoginCode code) async {
    if (!service.isCurrent) return;
    try {
      await service.action(code, 'cancel');
    } catch (_) {
      /* Short-lived server session will expire. */
    }
  }

  @override
  void dispose() {
    final old = _code;
    if (old != null &&
        phase != AppQRLoginPhase.success &&
        phase != AppQRLoginPhase.canceled) {
      unawaited(_cancelQuietly(old));
    }
    _disposed = true;
    _timer?.cancel();
    service.store.removeListener(_accountChanged);
    super.dispose();
  }
}
