import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'identity_verification_service.dart';

/// Returns collection completion only; the server remains the authority for approval.
class IdentityFaceSdk {
  IdentityFaceSdk({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('cn.kelance.bojian/identity_face');
  final MethodChannel _channel;
  String? _activeSession;
  Object? _activeAttempt;

  Future<void> checkAvailable() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('available');
      if (data?['available'] != true || data?['plan_id'] != '27030') {
        throw const ApiFailure('原生人脸核验资源不可用，请更新应用后重试');
      }
    } on MissingPluginException {
      throw const ApiFailure('当前版本未接入原生人脸核验，请更新应用');
    } on PlatformException {
      throw const ApiFailure('无法检查人脸核验组件，请重试');
    }
  }

  Future<bool> verify(
    IdentityFaceSession session, {
    required int accentColor,
    required bool dark,
  }) async {
    if (_activeSession != null) throw const ApiFailure('正在进行人脸核验，请勿重复操作');
    if (session.status != IdentityFaceStatus.pending ||
        session.nativeToken == null ||
        session.planID != '27030' ||
        !session.expiresAt.isAfter(DateTime.now())) {
      throw const ApiFailure('核验已过期，请返回重新识别');
    }
    final attempt = Object();
    _activeAttempt = attempt;
    _activeSession = session.id;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('verify', {
        'session_id': session.id,
        'native_token': session.nativeToken,
        'plan_id': session.planID,
        'match_source': 0,
        'consent': true,
        'accent_color': accentColor,
        'dark': dark,
      });
      if (!identical(_activeAttempt, attempt) ||
          data?['session_id'] != session.id ||
          data?['cancelled'] is! bool) {
        throw const ApiFailure('核验会话已变化，请重试');
      }
      return data!['cancelled'] != true;
    } on MissingPluginException {
      throw const ApiFailure('当前版本未接入原生人脸核验，请更新应用');
    } on PlatformException catch (error) {
      throw ApiFailure(error.message ?? '人脸核验未完成，请重试');
    } finally {
      if (identical(_activeAttempt, attempt)) {
        _activeSession = null;
        _activeAttempt = null;
      }
    }
  }

  Future<void> cancel() async {
    final id = _activeSession;
    _activeSession = null;
    _activeAttempt = null;
    if (id == null) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'session_id': id});
    } catch (_) {
      /* The native activity may already be closed. */
    }
  }
}
