import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'api/generated/auth.pb.dart' as auth;
import 'app_environment.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'captcha_dialog.dart';
import 'design.dart';
import 'login_widgets.dart';

/// The phone step of a WeChat or Douyin login. No session exists until the
/// phone is proved; leaving the page cancels the login.
class LoginPhoneBindingPage extends StatefulWidget {
  const LoginPhoneBindingPage({
    super.key,
    required this.store,
    required this.token,
    required this.provider,
  });

  final AppStore store;
  final String token;
  final String provider;

  @override
  State<LoginPhoneBindingPage> createState() => _LoginPhoneBindingPageState();
}

class _LoginPhoneBindingPageState extends State<LoginPhoneBindingPage> {
  final phone = TextEditingController(text: AppEnvironment.defaultTestPhone);
  final code = TextEditingController();
  late final int accountEpoch = widget.store.epoch;
  Timer? resendTimer;
  int countdown = 0;
  String? requestedPhone;
  String? status;
  String? error;
  bool requesting = false;
  bool submitting = false;

  bool get busy => requesting || submitting;
  bool get validPhone => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text);
  bool current() =>
      mounted &&
      widget.store.epoch == accountEpoch &&
      !widget.store.isAuthenticated;

  Future<void> requestCode() async {
    if (busy || countdown > 0) return;
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
      final outcome = await requestSmsCode(
        context,
        store: widget.store,
        phone: targetPhone,
        current: current,
        send: (token) {
          if (!current()) throw const ApiFailure('登录已取消');
          return widget.store.api.sendSMS(
            targetPhone,
            token,
            widget.store.headers,
          );
        },
      );
      if (!current() || outcome == null) return;
      final failure = outcome.error;
      if (failure != null) {
        setState(() => error = '$failure');
        return;
      }
      final response = outcome.response!;
      resendTimer?.cancel();
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
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  Future<void> submit() async {
    if (busy) return;
    final message = !validPhone
        ? '请输入正确的 11 位手机号'
        : requestedPhone != phone.text
        ? '请先获取当前手机号的验证码'
        : !RegExp(r'^\d{6}$').hasMatch(code.text)
        ? '请输入 6 位短信验证码'
        : null;
    if (message != null) {
      setState(() => error = message);
      return;
    }
    dismissKeyboard();
    final targetPhone = phone.text;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final auth.LoginResponse response = await widget.store
          .confirmLoginPhoneBinding(widget.token, targetPhone, code.text);
      if (!mounted || !current()) return;
      Navigator.pop(context, (response: response, phone: targetPhone));
    } catch (e) {
      if (current()) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !submitting,
    child: Scaffold(
      backgroundColor: context.loginCanvas,
      appBar: AppPageBar(backgroundColor: context.loginCanvas),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              key: const ValueKey('login-phone-binding-page'),
              padding: EdgeInsets.symmetric(
                horizontal: appPageHorizontalPadding,
                vertical: 24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '验证手机号',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.loginInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.provider}授权成功。为保障账号安全，请验证手机号后完成登录；该手机号已注册博简时，将直接登录原账号。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: context.loginMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LoginPhoneCodeFields(
                    keyPrefix: 'login-phone-binding',
                    phone: phone,
                    code: code,
                    enabled: !busy,
                    requesting: requesting,
                    countdown: countdown,
                    onRequestCode: requestCode,
                    onPhoneChanged: () => setState(() {
                      error = null;
                      status = null;
                      code.clear();
                    }),
                    onCodeChanged: () => setState(() => error = null),
                    onSubmitted: submit,
                  ),
                  if (error != null || status != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error ?? status!,
                        key: ValueKey(
                          error != null
                              ? 'login-phone-binding-error'
                              : 'login-phone-binding-status',
                        ),
                        style: TextStyle(
                          color: error != null
                              ? Theme.of(context).colorScheme.error
                              : context.loginMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('login-phone-binding-submit'),
                    onPressed: busy ? null : submit,
                    style: loginPrimaryButtonStyle(context),
                    child: Text(submitting ? '正在验证…' : '验证并登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    resendTimer?.cancel();
    phone.dispose();
    code.dispose();
    super.dispose();
  }
}
