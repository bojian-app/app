import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'api/generated/auth.pb.dart' as auth;
import 'app_environment.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'sms_code_flow.dart';
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

class _LoginPhoneBindingPageState extends State<LoginPhoneBindingPage>
    with SmsCodeFlow<LoginPhoneBindingPage> {
  @override
  AppStore get smsStore => widget.store;

  @override
  final phone = TextEditingController(text: AppEnvironment.defaultTestPhone);
  @override
  final code = TextEditingController();
  late final int accountEpoch = widget.store.epoch;
  @override
  String? error;
  bool submitting = false;

  bool get busy => requesting || submitting;
  bool current() =>
      mounted &&
      widget.store.epoch == accountEpoch &&
      !widget.store.isAuthenticated;

  Future<void> requestCode() async {
    if (busy || countdown > 0) return;
    await sendSmsCode(
      current: current,
      send: (targetPhone, token) {
        if (!current()) throw const ApiFailure('登录已取消');
        return widget.store.api.sendSMS(
          targetPhone,
          token,
          widget.store.headers,
        );
      },
    );
  }

  Future<void> submit() async {
    if (busy) return;
    final message = smsSubmitError;
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
                    '${widget.provider}授权成功。为保障账号安全，请验证手机号后完成登录；该手机号已注册Z优简时，将直接登录原账号。',
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
    phone.dispose();
    code.dispose();
    super.dispose();
  }
}
