// This is a generated file - do not edit.
//
// Generated from auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Empty extends $pb.GeneratedMessage {
  factory Empty() => Empty._();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Empty()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Empty()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: Empty.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Empty() / Empty.new instead')
  static Empty create() => Empty._();
  static $pb.GeneratedMessage $_createMessage() => Empty._();
  @$core.override
  Empty createEmptyInstance() => Empty._();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Empty>(Empty.$_createMessage);
  static Empty? _defaultInstance;
}

class Captcha extends $pb.GeneratedMessage {
  factory Captcha({
    $core.String? id,
    $core.String? masterImageDataUrl,
    $core.String? thumbImageDataUrl,
  }) {
    final result = Captcha._();
    if (id != null) result.id = id;
    if (masterImageDataUrl != null)
      result.masterImageDataUrl = masterImageDataUrl;
    if (thumbImageDataUrl != null) result.thumbImageDataUrl = thumbImageDataUrl;
    return result;
  }

  Captcha._();

  factory Captcha.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Captcha()..mergeFromBuffer(data, registry);
  factory Captcha.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Captcha()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Captcha',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: Captcha.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'masterImageDataUrl')
    ..aOS(3, _omitFieldNames ? '' : 'thumbImageDataUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Captcha clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Captcha copyWith(void Function(Captcha) updates) =>
      super.copyWith((message) => updates(message as Captcha)) as Captcha;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Captcha() / Captcha.new instead')
  static Captcha create() => Captcha._();
  static $pb.GeneratedMessage $_createMessage() => Captcha._();
  @$core.override
  Captcha createEmptyInstance() => Captcha._();
  @$core.pragma('dart2js:noInline')
  static Captcha getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Captcha>(Captcha.$_createMessage);
  static Captcha? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get masterImageDataUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set masterImageDataUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMasterImageDataUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearMasterImageDataUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get thumbImageDataUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set thumbImageDataUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasThumbImageDataUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearThumbImageDataUrl() => $_clearField(3);
}

class VerifyCaptchaRequest extends $pb.GeneratedMessage {
  factory VerifyCaptchaRequest({
    $core.String? id,
    $core.int? angle,
  }) {
    final result = VerifyCaptchaRequest._();
    if (id != null) result.id = id;
    if (angle != null) result.angle = angle;
    return result;
  }

  VerifyCaptchaRequest._();

  factory VerifyCaptchaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VerifyCaptchaRequest()..mergeFromBuffer(data, registry);
  factory VerifyCaptchaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VerifyCaptchaRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VerifyCaptchaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: VerifyCaptchaRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'angle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyCaptchaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyCaptchaRequest copyWith(void Function(VerifyCaptchaRequest) updates) =>
      super.copyWith((message) => updates(message as VerifyCaptchaRequest))
          as VerifyCaptchaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use VerifyCaptchaRequest() / VerifyCaptchaRequest.new instead')
  static VerifyCaptchaRequest create() => VerifyCaptchaRequest._();
  static $pb.GeneratedMessage $_createMessage() => VerifyCaptchaRequest._();
  @$core.override
  VerifyCaptchaRequest createEmptyInstance() => VerifyCaptchaRequest._();
  @$core.pragma('dart2js:noInline')
  static VerifyCaptchaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VerifyCaptchaRequest>(
          VerifyCaptchaRequest.$_createMessage);
  static VerifyCaptchaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get angle => $_getIZ(1);
  @$pb.TagNumber(2)
  set angle($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAngle() => $_has(1);
  @$pb.TagNumber(2)
  void clearAngle() => $_clearField(2);
}

class CaptchaVerification extends $pb.GeneratedMessage {
  factory CaptchaVerification({
    $core.String? captchaToken,
  }) {
    final result = CaptchaVerification._();
    if (captchaToken != null) result.captchaToken = captchaToken;
    return result;
  }

  CaptchaVerification._();

  factory CaptchaVerification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CaptchaVerification()..mergeFromBuffer(data, registry);
  factory CaptchaVerification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CaptchaVerification()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CaptchaVerification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: CaptchaVerification.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'captchaToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CaptchaVerification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CaptchaVerification copyWith(void Function(CaptchaVerification) updates) =>
      super.copyWith((message) => updates(message as CaptchaVerification))
          as CaptchaVerification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use CaptchaVerification() / CaptchaVerification.new instead')
  static CaptchaVerification create() => CaptchaVerification._();
  static $pb.GeneratedMessage $_createMessage() => CaptchaVerification._();
  @$core.override
  CaptchaVerification createEmptyInstance() => CaptchaVerification._();
  @$core.pragma('dart2js:noInline')
  static CaptchaVerification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CaptchaVerification>(
          CaptchaVerification.$_createMessage);
  static CaptchaVerification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get captchaToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set captchaToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCaptchaToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearCaptchaToken() => $_clearField(1);
}

class SendSMSRequest extends $pb.GeneratedMessage {
  factory SendSMSRequest({
    $core.String? phone,
    $core.String? captchaToken,
    $core.String? purpose,
  }) {
    final result = SendSMSRequest._();
    if (phone != null) result.phone = phone;
    if (captchaToken != null) result.captchaToken = captchaToken;
    if (purpose != null) result.purpose = purpose;
    return result;
  }

  SendSMSRequest._();

  factory SendSMSRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendSMSRequest()..mergeFromBuffer(data, registry);
  factory SendSMSRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendSMSRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendSMSRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: SendSMSRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'phone')
    ..aOS(2, _omitFieldNames ? '' : 'captchaToken')
    ..aOS(3, _omitFieldNames ? '' : 'purpose')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendSMSRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendSMSRequest copyWith(void Function(SendSMSRequest) updates) =>
      super.copyWith((message) => updates(message as SendSMSRequest))
          as SendSMSRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendSMSRequest() / SendSMSRequest.new instead')
  static SendSMSRequest create() => SendSMSRequest._();
  static $pb.GeneratedMessage $_createMessage() => SendSMSRequest._();
  @$core.override
  SendSMSRequest createEmptyInstance() => SendSMSRequest._();
  @$core.pragma('dart2js:noInline')
  static SendSMSRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendSMSRequest>(
          SendSMSRequest.$_createMessage);
  static SendSMSRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get phone => $_getSZ(0);
  @$pb.TagNumber(1)
  set phone($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPhone() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhone() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get captchaToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set captchaToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCaptchaToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearCaptchaToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get purpose => $_getSZ(2);
  @$pb.TagNumber(3)
  set purpose($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPurpose() => $_has(2);
  @$pb.TagNumber(3)
  void clearPurpose() => $_clearField(3);
}

class SMSResponse extends $pb.GeneratedMessage {
  factory SMSResponse({
    $core.int? retryAfterSeconds,
    $core.String? deliveryStatus,
  }) {
    final result = SMSResponse._();
    if (retryAfterSeconds != null) result.retryAfterSeconds = retryAfterSeconds;
    if (deliveryStatus != null) result.deliveryStatus = deliveryStatus;
    return result;
  }

  SMSResponse._();

  factory SMSResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SMSResponse()..mergeFromBuffer(data, registry);
  factory SMSResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SMSResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SMSResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: SMSResponse.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'retryAfterSeconds')
    ..aOS(2, _omitFieldNames ? '' : 'deliveryStatus')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SMSResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SMSResponse copyWith(void Function(SMSResponse) updates) =>
      super.copyWith((message) => updates(message as SMSResponse))
          as SMSResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SMSResponse() / SMSResponse.new instead')
  static SMSResponse create() => SMSResponse._();
  static $pb.GeneratedMessage $_createMessage() => SMSResponse._();
  @$core.override
  SMSResponse createEmptyInstance() => SMSResponse._();
  @$core.pragma('dart2js:noInline')
  static SMSResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SMSResponse>(
          SMSResponse.$_createMessage);
  static SMSResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get retryAfterSeconds => $_getIZ(0);
  @$pb.TagNumber(1)
  set retryAfterSeconds($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRetryAfterSeconds() => $_has(0);
  @$pb.TagNumber(1)
  void clearRetryAfterSeconds() => $_clearField(1);

  /// SUBMITTED means accepted; only a successful receipt is DELIVERED.
  @$pb.TagNumber(2)
  $core.String get deliveryStatus => $_getSZ(1);
  @$pb.TagNumber(2)
  set deliveryStatus($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeliveryStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeliveryStatus() => $_clearField(2);
}

class PhoneLoginRequest extends $pb.GeneratedMessage {
  factory PhoneLoginRequest({
    $core.String? phone,
    $core.String? code,
  }) {
    final result = PhoneLoginRequest._();
    if (phone != null) result.phone = phone;
    if (code != null) result.code = code;
    return result;
  }

  PhoneLoginRequest._();

  factory PhoneLoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PhoneLoginRequest()..mergeFromBuffer(data, registry);
  factory PhoneLoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PhoneLoginRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PhoneLoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: PhoneLoginRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'phone')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhoneLoginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhoneLoginRequest copyWith(void Function(PhoneLoginRequest) updates) =>
      super.copyWith((message) => updates(message as PhoneLoginRequest))
          as PhoneLoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PhoneLoginRequest() / PhoneLoginRequest.new instead')
  static PhoneLoginRequest create() => PhoneLoginRequest._();
  static $pb.GeneratedMessage $_createMessage() => PhoneLoginRequest._();
  @$core.override
  PhoneLoginRequest createEmptyInstance() => PhoneLoginRequest._();
  @$core.pragma('dart2js:noInline')
  static PhoneLoginRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PhoneLoginRequest>(
          PhoneLoginRequest.$_createMessage);
  static PhoneLoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get phone => $_getSZ(0);
  @$pb.TagNumber(1)
  set phone($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPhone() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhone() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);
}

class ConfirmRegistrationRequest extends $pb.GeneratedMessage {
  factory ConfirmRegistrationRequest({
    $core.String? registrationToken,
    $core.bool? confirmed,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        agreementVersions,
  }) {
    final result = ConfirmRegistrationRequest._();
    if (registrationToken != null) result.registrationToken = registrationToken;
    if (confirmed != null) result.confirmed = confirmed;
    if (agreementVersions != null)
      result.agreementVersions.addEntries(agreementVersions);
    return result;
  }

  ConfirmRegistrationRequest._();

  factory ConfirmRegistrationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfirmRegistrationRequest()..mergeFromBuffer(data, registry);
  factory ConfirmRegistrationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfirmRegistrationRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfirmRegistrationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: ConfirmRegistrationRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'registrationToken')
    ..aOB(2, _omitFieldNames ? '' : 'confirmed')
    ..m<$core.String, $core.String>(
        3, _omitFieldNames ? '' : 'agreementVersions',
        entryClassName: 'ConfirmRegistrationRequest.AgreementVersionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bojian.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmRegistrationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmRegistrationRequest copyWith(
          void Function(ConfirmRegistrationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ConfirmRegistrationRequest))
          as ConfirmRegistrationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ConfirmRegistrationRequest() / ConfirmRegistrationRequest.new instead')
  static ConfirmRegistrationRequest create() => ConfirmRegistrationRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      ConfirmRegistrationRequest._();
  @$core.override
  ConfirmRegistrationRequest createEmptyInstance() =>
      ConfirmRegistrationRequest._();
  @$core.pragma('dart2js:noInline')
  static ConfirmRegistrationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfirmRegistrationRequest>(
          ConfirmRegistrationRequest.$_createMessage);
  static ConfirmRegistrationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get registrationToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set registrationToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRegistrationToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegistrationToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get confirmed => $_getBF(1);
  @$pb.TagNumber(2)
  set confirmed($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConfirmed() => $_has(1);
  @$pb.TagNumber(2)
  void clearConfirmed() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get agreementVersions => $_getMap(2);
}

class RefreshTokenRequest extends $pb.GeneratedMessage {
  factory RefreshTokenRequest({
    $core.String? refreshToken,
  }) {
    final result = RefreshTokenRequest._();
    if (refreshToken != null) result.refreshToken = refreshToken;
    return result;
  }

  RefreshTokenRequest._();

  factory RefreshTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshTokenRequest()..mergeFromBuffer(data, registry);
  factory RefreshTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RefreshTokenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: RefreshTokenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'refreshToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenRequest copyWith(void Function(RefreshTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RefreshTokenRequest))
          as RefreshTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RefreshTokenRequest() / RefreshTokenRequest.new instead')
  static RefreshTokenRequest create() => RefreshTokenRequest._();
  static $pb.GeneratedMessage $_createMessage() => RefreshTokenRequest._();
  @$core.override
  RefreshTokenRequest createEmptyInstance() => RefreshTokenRequest._();
  @$core.pragma('dart2js:noInline')
  static RefreshTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshTokenRequest>(
          RefreshTokenRequest.$_createMessage);
  static RefreshTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refreshToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set refreshToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefreshToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefreshToken() => $_clearField(1);
}

class UserIdentity extends $pb.GeneratedMessage {
  factory UserIdentity({
    $fixnum.Int64? id,
    $core.String? publicId,
  }) {
    final result = UserIdentity._();
    if (id != null) result.id = id;
    if (publicId != null) result.publicId = publicId;
    return result;
  }

  UserIdentity._();

  factory UserIdentity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserIdentity()..mergeFromBuffer(data, registry);
  factory UserIdentity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UserIdentity()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserIdentity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: UserIdentity.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'publicId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserIdentity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserIdentity copyWith(void Function(UserIdentity) updates) =>
      super.copyWith((message) => updates(message as UserIdentity))
          as UserIdentity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UserIdentity() / UserIdentity.new instead')
  static UserIdentity create() => UserIdentity._();
  static $pb.GeneratedMessage $_createMessage() => UserIdentity._();
  @$core.override
  UserIdentity createEmptyInstance() => UserIdentity._();
  @$core.pragma('dart2js:noInline')
  static UserIdentity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserIdentity>(
          UserIdentity.$_createMessage);
  static UserIdentity? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get publicId => $_getSZ(1);
  @$pb.TagNumber(2)
  set publicId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPublicId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPublicId() => $_clearField(2);
}

class LoginResponse extends $pb.GeneratedMessage {
  factory LoginResponse({
    $core.String? accessToken,
    $fixnum.Int64? accessExpiresInSeconds,
    $core.String? refreshToken,
    $core.String? refreshExpiresAt,
    UserIdentity? user,
    $core.bool? registrationRequired,
    $core.String? registrationToken,
    $core.int? registrationExpiresInSeconds,
  }) {
    final result = LoginResponse._();
    if (accessToken != null) result.accessToken = accessToken;
    if (accessExpiresInSeconds != null)
      result.accessExpiresInSeconds = accessExpiresInSeconds;
    if (refreshToken != null) result.refreshToken = refreshToken;
    if (refreshExpiresAt != null) result.refreshExpiresAt = refreshExpiresAt;
    if (user != null) result.user = user;
    if (registrationRequired != null)
      result.registrationRequired = registrationRequired;
    if (registrationToken != null) result.registrationToken = registrationToken;
    if (registrationExpiresInSeconds != null)
      result.registrationExpiresInSeconds = registrationExpiresInSeconds;
    return result;
  }

  LoginResponse._();

  factory LoginResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginResponse()..mergeFromBuffer(data, registry);
  factory LoginResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: LoginResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aInt64(2, _omitFieldNames ? '' : 'accessExpiresInSeconds')
    ..aOS(3, _omitFieldNames ? '' : 'refreshToken')
    ..aOS(4, _omitFieldNames ? '' : 'refreshExpiresAt')
    ..aOM<UserIdentity>(5, _omitFieldNames ? '' : 'user',
        subBuilder: UserIdentity.$_createMessage)
    ..aOB(6, _omitFieldNames ? '' : 'registrationRequired')
    ..aOS(7, _omitFieldNames ? '' : 'registrationToken')
    ..aI(8, _omitFieldNames ? '' : 'registrationExpiresInSeconds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse copyWith(void Function(LoginResponse) updates) =>
      super.copyWith((message) => updates(message as LoginResponse))
          as LoginResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LoginResponse() / LoginResponse.new instead')
  static LoginResponse create() => LoginResponse._();
  static $pb.GeneratedMessage $_createMessage() => LoginResponse._();
  @$core.override
  LoginResponse createEmptyInstance() => LoginResponse._();
  @$core.pragma('dart2js:noInline')
  static LoginResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoginResponse>(
          LoginResponse.$_createMessage);
  static LoginResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get accessExpiresInSeconds => $_getI64(1);
  @$pb.TagNumber(2)
  set accessExpiresInSeconds($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccessExpiresInSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccessExpiresInSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get refreshToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set refreshToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefreshToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefreshToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get refreshExpiresAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set refreshExpiresAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRefreshExpiresAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefreshExpiresAt() => $_clearField(4);

  @$pb.TagNumber(5)
  UserIdentity get user => $_getN(4);
  @$pb.TagNumber(5)
  set user(UserIdentity value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUser() => $_has(4);
  @$pb.TagNumber(5)
  void clearUser() => $_clearField(5);
  @$pb.TagNumber(5)
  UserIdentity ensureUser() => $_ensure(4);

  /// No account or login session exists until registration is confirmed.
  @$pb.TagNumber(6)
  $core.bool get registrationRequired => $_getBF(5);
  @$pb.TagNumber(6)
  set registrationRequired($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRegistrationRequired() => $_has(5);
  @$pb.TagNumber(6)
  void clearRegistrationRequired() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get registrationToken => $_getSZ(6);
  @$pb.TagNumber(7)
  set registrationToken($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRegistrationToken() => $_has(6);
  @$pb.TagNumber(7)
  void clearRegistrationToken() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get registrationExpiresInSeconds => $_getIZ(7);
  @$pb.TagNumber(8)
  set registrationExpiresInSeconds($core.int value) =>
      $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRegistrationExpiresInSeconds() => $_has(7);
  @$pb.TagNumber(8)
  void clearRegistrationExpiresInSeconds() => $_clearField(8);
}

class TokenResponse extends $pb.GeneratedMessage {
  factory TokenResponse({
    $core.String? accessToken,
    $fixnum.Int64? accessExpiresInSeconds,
    $core.String? refreshToken,
    $core.String? refreshExpiresAt,
  }) {
    final result = TokenResponse._();
    if (accessToken != null) result.accessToken = accessToken;
    if (accessExpiresInSeconds != null)
      result.accessExpiresInSeconds = accessExpiresInSeconds;
    if (refreshToken != null) result.refreshToken = refreshToken;
    if (refreshExpiresAt != null) result.refreshExpiresAt = refreshExpiresAt;
    return result;
  }

  TokenResponse._();

  factory TokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TokenResponse()..mergeFromBuffer(data, registry);
  factory TokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TokenResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: TokenResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aInt64(2, _omitFieldNames ? '' : 'accessExpiresInSeconds')
    ..aOS(3, _omitFieldNames ? '' : 'refreshToken')
    ..aOS(4, _omitFieldNames ? '' : 'refreshExpiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TokenResponse copyWith(void Function(TokenResponse) updates) =>
      super.copyWith((message) => updates(message as TokenResponse))
          as TokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TokenResponse() / TokenResponse.new instead')
  static TokenResponse create() => TokenResponse._();
  static $pb.GeneratedMessage $_createMessage() => TokenResponse._();
  @$core.override
  TokenResponse createEmptyInstance() => TokenResponse._();
  @$core.pragma('dart2js:noInline')
  static TokenResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TokenResponse>(
          TokenResponse.$_createMessage);
  static TokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get accessExpiresInSeconds => $_getI64(1);
  @$pb.TagNumber(2)
  set accessExpiresInSeconds($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccessExpiresInSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccessExpiresInSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get refreshToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set refreshToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefreshToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefreshToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get refreshExpiresAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set refreshExpiresAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRefreshExpiresAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefreshExpiresAt() => $_clearField(4);
}

class CreateWeChatQRRequest extends $pb.GeneratedMessage {
  factory CreateWeChatQRRequest({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        agreementVersions,
  }) {
    final result = CreateWeChatQRRequest._();
    if (agreementVersions != null)
      result.agreementVersions.addEntries(agreementVersions);
    return result;
  }

  CreateWeChatQRRequest._();

  factory CreateWeChatQRRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateWeChatQRRequest()..mergeFromBuffer(data, registry);
  factory CreateWeChatQRRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateWeChatQRRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateWeChatQRRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: CreateWeChatQRRequest.$_createMessage)
    ..m<$core.String, $core.String>(
        1, _omitFieldNames ? '' : 'agreementVersions',
        entryClassName: 'CreateWeChatQRRequest.AgreementVersionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('bojian.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWeChatQRRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWeChatQRRequest copyWith(
          void Function(CreateWeChatQRRequest) updates) =>
      super.copyWith((message) => updates(message as CreateWeChatQRRequest))
          as CreateWeChatQRRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateWeChatQRRequest() / CreateWeChatQRRequest.new instead')
  static CreateWeChatQRRequest create() => CreateWeChatQRRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateWeChatQRRequest._();
  @$core.override
  CreateWeChatQRRequest createEmptyInstance() => CreateWeChatQRRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateWeChatQRRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateWeChatQRRequest>(
          CreateWeChatQRRequest.$_createMessage);
  static CreateWeChatQRRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get agreementVersions => $_getMap(0);
}

class WeChatQRRequest extends $pb.GeneratedMessage {
  factory WeChatQRRequest({
    $fixnum.Int64? id,
  }) {
    final result = WeChatQRRequest._();
    if (id != null) result.id = id;
    return result;
  }

  WeChatQRRequest._();

  factory WeChatQRRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WeChatQRRequest()..mergeFromBuffer(data, registry);
  factory WeChatQRRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WeChatQRRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WeChatQRRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: WeChatQRRequest.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeChatQRRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeChatQRRequest copyWith(void Function(WeChatQRRequest) updates) =>
      super.copyWith((message) => updates(message as WeChatQRRequest))
          as WeChatQRRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WeChatQRRequest() / WeChatQRRequest.new instead')
  static WeChatQRRequest create() => WeChatQRRequest._();
  static $pb.GeneratedMessage $_createMessage() => WeChatQRRequest._();
  @$core.override
  WeChatQRRequest createEmptyInstance() => WeChatQRRequest._();
  @$core.pragma('dart2js:noInline')
  static WeChatQRRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WeChatQRRequest>(
          WeChatQRRequest.$_createMessage);
  static WeChatQRRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class WeChatQRSession extends $pb.GeneratedMessage {
  factory WeChatQRSession({
    $fixnum.Int64? id,
    $core.String? status,
    $core.String? qrUrl,
    $core.int? pollAfterSeconds,
  }) {
    final result = WeChatQRSession._();
    if (id != null) result.id = id;
    if (status != null) result.status = status;
    if (qrUrl != null) result.qrUrl = qrUrl;
    if (pollAfterSeconds != null) result.pollAfterSeconds = pollAfterSeconds;
    return result;
  }

  WeChatQRSession._();

  factory WeChatQRSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WeChatQRSession()..mergeFromBuffer(data, registry);
  factory WeChatQRSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WeChatQRSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WeChatQRSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bojian.v1'),
      createEmptyInstance: WeChatQRSession.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..aOS(3, _omitFieldNames ? '' : 'qrUrl')
    ..aI(4, _omitFieldNames ? '' : 'pollAfterSeconds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeChatQRSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeChatQRSession copyWith(void Function(WeChatQRSession) updates) =>
      super.copyWith((message) => updates(message as WeChatQRSession))
          as WeChatQRSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WeChatQRSession() / WeChatQRSession.new instead')
  static WeChatQRSession create() => WeChatQRSession._();
  static $pb.GeneratedMessage $_createMessage() => WeChatQRSession._();
  @$core.override
  WeChatQRSession createEmptyInstance() => WeChatQRSession._();
  @$core.pragma('dart2js:noInline')
  static WeChatQRSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WeChatQRSession>(
          WeChatQRSession.$_createMessage);
  static WeChatQRSession? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get qrUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set qrUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQrUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearQrUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get pollAfterSeconds => $_getIZ(3);
  @$pb.TagNumber(4)
  set pollAfterSeconds($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPollAfterSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearPollAfterSeconds() => $_clearField(4);
}

/// Login responses are typed. Credentials are transported only over TLS outside loopback.
class AuthenticationServiceApi {
  final $pb.RpcClient _client;

  AuthenticationServiceApi(this._client);

  $async.Future<Captcha> createCaptcha($pb.ClientContext? ctx, Empty request) =>
      _client.invoke<Captcha>(
          ctx, 'AuthenticationService', 'CreateCaptcha', request, Captcha());
  $async.Future<CaptchaVerification> verifyCaptcha(
          $pb.ClientContext? ctx, VerifyCaptchaRequest request) =>
      _client.invoke<CaptchaVerification>(ctx, 'AuthenticationService',
          'VerifyCaptcha', request, CaptchaVerification());
  $async.Future<SMSResponse> sendSMS(
          $pb.ClientContext? ctx, SendSMSRequest request) =>
      _client.invoke<SMSResponse>(
          ctx, 'AuthenticationService', 'SendSMS', request, SMSResponse());
  $async.Future<LoginResponse> phoneLogin(
          $pb.ClientContext? ctx, PhoneLoginRequest request) =>
      _client.invoke<LoginResponse>(
          ctx, 'AuthenticationService', 'PhoneLogin', request, LoginResponse());
  $async.Future<LoginResponse> confirmRegistration(
          $pb.ClientContext? ctx, ConfirmRegistrationRequest request) =>
      _client.invoke<LoginResponse>(ctx, 'AuthenticationService',
          'ConfirmRegistration', request, LoginResponse());
  $async.Future<TokenResponse> refreshToken(
          $pb.ClientContext? ctx, RefreshTokenRequest request) =>
      _client.invoke<TokenResponse>(ctx, 'AuthenticationService',
          'RefreshToken', request, TokenResponse());
  $async.Future<WeChatQRSession> createWeChatQR(
          $pb.ClientContext? ctx, CreateWeChatQRRequest request) =>
      _client.invoke<WeChatQRSession>(ctx, 'AuthenticationService',
          'CreateWeChatQR', request, WeChatQRSession());
  $async.Future<WeChatQRSession> getWeChatQR(
          $pb.ClientContext? ctx, WeChatQRRequest request) =>
      _client.invoke<WeChatQRSession>(ctx, 'AuthenticationService',
          'GetWeChatQR', request, WeChatQRSession());
  $async.Future<WeChatQRSession> refreshWeChatQR(
          $pb.ClientContext? ctx, WeChatQRRequest request) =>
      _client.invoke<WeChatQRSession>(ctx, 'AuthenticationService',
          'RefreshWeChatQR', request, WeChatQRSession());
  $async.Future<LoginResponse> exchangeWeChatQR(
          $pb.ClientContext? ctx, WeChatQRRequest request) =>
      _client.invoke<LoginResponse>(ctx, 'AuthenticationService',
          'ExchangeWeChatQR', request, LoginResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
