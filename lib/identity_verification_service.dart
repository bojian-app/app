import 'dart:convert';
import 'dart:typed_data';

import 'api/bojian_api.dart';
import 'app_store.dart';

const identityConsentVersion = 'baidu-identity-2026-10-v1';
const maximumIdentityImageBytes = 4 * 1024 * 1024;

class RecognizedIdentity {
  const RecognizedIdentity({
    required this.token,
    required this.name,
    required this.maskedNumber,
    required this.validFrom,
    required this.validUntil,
    required this.longTerm,
    required this.expiresAt,
  });
  final String token, name, maskedNumber, validFrom, validUntil;
  final bool longTerm;
  final DateTime expiresAt;

  factory RecognizedIdentity.fromMap(Map<String, dynamic> data) {
    final token = data['ocr_token'];
    final name = data['name'];
    final number = data['holder_id_masked'];
    final from = data['valid_from'];
    final until = data['valid_until'];
    final expires = DateTime.tryParse('${data['expires_at'] ?? ''}');
    if (token is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token) ||
        name is! String ||
        name.trim().isEmpty ||
        number is! String ||
        number.isEmpty ||
        from is! String ||
        DateTime.tryParse(from) == null ||
        until is! String ||
        DateTime.tryParse(until) == null ||
        expires == null) {
      throw const ApiFailure('身份证识别结果不完整，请重新识别');
    }
    return RecognizedIdentity(
      token: token,
      name: name,
      maskedNumber: number,
      validFrom: from,
      validUntil: until,
      longTerm: data['long_term'] == true,
      expiresAt: expires,
    );
  }
}

enum IdentityFaceStatus { pending, verified, failed, expired }

class IdentityFaceSession {
  const IdentityFaceSession({
    required this.id,
    required this.status,
    required this.expiresAt,
    this.nativeToken,
    this.planID,
    this.reason,
    this.verificationID,
  });
  final String id;
  final IdentityFaceStatus status;
  final DateTime expiresAt;
  final String? nativeToken, planID;
  final String? reason;
  final int? verificationID;

  factory IdentityFaceSession.fromMap(Map<String, dynamic> data) {
    final id = data['session_id'];
    final status = switch (data['status']) {
      'PENDING' => IdentityFaceStatus.pending,
      'VERIFIED' => IdentityFaceStatus.verified,
      'FAILED' => IdentityFaceStatus.failed,
      'EXPIRED' => IdentityFaceStatus.expired,
      _ => throw const ApiFailure('核验状态无效，请稍后重试'),
    };
    final expires = DateTime.tryParse('${data['expires_at'] ?? ''}');
    final nativeToken = data['native_token'];
    final planID = data['plan_id'];
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(id) ||
        expires == null ||
        (status == IdentityFaceStatus.pending &&
            (data['flow'] != 'APP' ||
                data['match_source'] != 0 ||
                nativeToken is! String ||
                nativeToken.isEmpty ||
                nativeToken.length > 512 ||
                planID != '27030')) ||
        (status == IdentityFaceStatus.verified &&
            integer(data['verification_id']) <= 0)) {
      throw const ApiFailure('核验结果或原生方案参数无效，请稍后重试');
    }
    return IdentityFaceSession(
      id: id,
      status: status,
      expiresAt: expires,
      nativeToken: status == IdentityFaceStatus.pending
          ? nativeToken as String
          : null,
      planID: status == IdentityFaceStatus.pending ? planID as String : null,
      reason: data['public_failure_reason'] is String
          ? data['public_failure_reason']
          : null,
      verificationID: status == IdentityFaceStatus.verified
          ? integer(data['verification_id'])
          : null,
    );
  }
}

class IdentityVerificationService {
  const IdentityVerificationService(this.store);
  final AppStore store;

  Future<void> checkAvailable() async {
    try {
      final response = await store.request(
        'GetMeIdentityVerificationCapabilities',
      );
      if (response.data['available'] != true ||
          response.data['provider'] != 'BAIDU' ||
          response.data['flow'] != 'APP') {
        throw const ApiFailure('百度实名认证服务暂不可用，请稍后重试');
      }
      if (response.data['consent_version'] != identityConsentVersion) {
        throw const ApiFailure('认证说明已更新，请更新应用后重试');
      }
    } on ApiFailure catch (error) {
      if (error.code == 'NOT_FOUND' || error.code == 'METHOD_NOT_ALLOWED') {
        throw const ApiFailure('实名认证服务暂未部署，请稍后重试');
      }
      rethrow;
    }
  }

  Future<RecognizedIdentity> recognize(Uint8List front, Uint8List back) async {
    if (front.isEmpty ||
        back.isEmpty ||
        front.length > maximumIdentityImageBytes ||
        back.length > maximumIdentityImageBytes) {
      throw const ApiFailure('照片处理后过大，请重新拍摄清晰的证件照片');
    }
    final result = await store.request(
      'PostMeIdentityVerificationOCR',
      body: {
        'front_image': base64Encode(front),
        'back_image': base64Encode(back),
        'consent_version': identityConsentVersion,
      },
    );
    return RecognizedIdentity.fromMap(result.data);
  }

  Future<IdentityFaceSession> start(RecognizedIdentity identity) async {
    if (!identity.expiresAt.isAfter(DateTime.now())) {
      throw const ApiFailure('证件识别已过期，请返回重新识别');
    }
    final result = await store.request(
      'PostMeIdentityVerificationFaceSessions',
      body: {
        'ocr_token': identity.token,
        'identity_confirmed': true,
        'consent_version': identityConsentVersion,
      },
    );
    return IdentityFaceSession.fromMap(result.data);
  }

  Future<IdentityFaceSession> refresh(IdentityFaceSession session) async {
    if (!session.expiresAt.isAfter(DateTime.now())) {
      throw const ApiFailure('核验已过期，请返回重新认证');
    }
    final result = await store.request(
      'PostMeIdentityVerificationFaceSessionsSessionRefresh',
      path: {'session': session.id},
      body: {},
    );
    final updated = IdentityFaceSession.fromMap(result.data);
    if (updated.id != session.id) throw const ApiFailure('核验会话不匹配，请重新认证');
    return updated;
  }
}
