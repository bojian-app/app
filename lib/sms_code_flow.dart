import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api/generated/auth.pb.dart' as auth;
import 'app_environment.dart';
import 'app_store.dart';
import 'captcha_dialog.dart';
import 'design.dart';

/// Shared phone + SMS code state for sign-in and phone binding forms:
/// captcha, resend countdown, test-code autofill and submit validation.
mixin SmsCodeFlow<T extends StatefulWidget> on State<T> {
  TextEditingController get phone;
  TextEditingController get code;
  AppStore get smsStore;
  String? get error;
  set error(String? value);

  Timer? _resendTimer;
  int countdown = 0;
  String? requestedPhone;
  String? status;
  bool requesting = false;

  bool get validPhone => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text);

  /// The first problem blocking submission, or null when phone and code are
  /// ready.
  String? get smsSubmitError => !validPhone
      ? '请输入正确的 11 位手机号'
      : requestedPhone != phone.text
      ? '请先获取当前手机号的验证码'
      : !RegExp(r'^\d{6}$').hasMatch(code.text)
      ? '请输入 6 位短信验证码'
      : null;

  /// Requests a code for the current phone. [beforeSend] may cancel, for
  /// example when the user declines the agreement.
  Future<void> sendSmsCode({
    required bool Function() current,
    required Future<auth.SMSResponse> Function(String phone, String token) send,
    Future<bool> Function()? beforeSend,
  }) async {
    if (!validPhone) {
      setState(() => error = '请输入正确的 11 位手机号');
      return;
    }
    final targetPhone = phone.text;
    dismissKeyboard();
    setState(() {
      requesting = true;
      error = null;
      status = null;
    });
    try {
      if (beforeSend != null &&
          (!await beforeSend() || !mounted || !current())) {
        return;
      }
      if (!mounted) return;
      final outcome = await requestSmsCode(
        context,
        store: smsStore,
        phone: targetPhone,
        current: current,
        send: (token) => send(targetPhone, token),
      );
      if (!current() || outcome == null) return;
      final failure = outcome.error;
      if (failure != null) {
        setState(() => error = '$failure');
        return;
      }
      final response = outcome.response!;
      _resendTimer?.cancel();
      setState(() {
        requestedPhone = targetPhone;
        countdown = response.retryAfterSeconds.clamp(1, 3600);
        status = '短信验证码已发送，请注意查收';
        final testCode = AppEnvironment.smsTestCode(
          targetPhone,
          response.testCode,
        );
        if (testCode.isNotEmpty) {
          code.text = testCode;
          status = '测试验证码已自动填入，未发送短信';
        }
      });
      final availableAt = DateTime.now().add(Duration(seconds: countdown));
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!current()) {
          timer.cancel();
          return;
        }
        setState(
          () => countdown =
              ((availableAt.difference(DateTime.now()).inMilliseconds + 999) ~/
                      1000)
                  .clamp(0, 3600),
        );
        if (countdown == 0) timer.cancel();
      });
    } catch (e) {
      if (current()) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
