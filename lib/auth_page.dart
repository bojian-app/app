import 'dart:async';

import 'agreement_dialog.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'confirmation_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'design.dart';
import 'login_widgets.dart';
import 'login_illustration.dart';
import 'api/bojian_api.dart';
import 'captcha_dialog.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(refreshState);
  }

  void refreshState() {
    if (mounted) setState(() {});
  }

  final inviteCode = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  Timer? resendTimer;
  int countdown = 0;
  String? requestedPhone;
  String? smsStatus;
  bool requestingCode = false;
  bool agreed = false;
  String? signingInWith;
  bool get submitting => signingInWith != null || requestingCode;
  bool get disabled => submitting || widget.store.restoring;
  bool get validPhone => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text);
  String? error;

  void changeAgreement(bool? value) => setState(() {
    agreed = value ?? false;
    error = null;
  });

  Future<bool> confirmAgreement() async {
    if (agreed) return true;
    final accepted = await showAppDialog<bool>(
      context,
      barrierDismissible: true,
      builder: (_) => AgreementDialog(
        onOpenTerms: () => legal(false),
        onOpenPrivacy: () => legal(true),
      ),
    );
    if (!mounted || accepted != true) return false;
    setState(() {
      agreed = true;
      error = null;
    });
    return true;
  }

  Future<void> signIn({bool douyin = false}) async {
    if (submitting || widget.store.restoring) return;
    final provider = douyin ? '抖音' : '微信';
    dismissKeyboard();
    setState(() {
      signingInWith = provider;
      error = null;
    });
    try {
      if (!await confirmAgreement() || !mounted) return;
      if (douyin) {
        await widget.store.signInWithDouyin(
          confirmRegistration: confirmRegistration,
        );
      } else {
        await widget.store.signInWithWeChat(
          confirmRegistration: confirmRegistration,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => signingInWith = null);
    }
  }

  Future<void> requestCode() async {
    if (disabled || countdown > 0) return;
    if (!validPhone) {
      setState(() => error = '请输入正确的 11 位手机号');
      return;
    }
    final version = widget.store.epoch;
    bool current() =>
        mounted &&
        widget.store.epoch == version &&
        !widget.store.isAuthenticated;
    final targetPhone = phone.text;
    dismissKeyboard();
    setState(() {
      requestingCode = true;
      error = null;
      smsStatus = null;
    });
    try {
      if (!await confirmAgreement() || !current()) return;
      final challenge = await widget.store.api.createCaptcha(
        widget.store.headers,
      );
      if (!mounted || !current()) return;
      final outcome = await showDialog<SmsRequestOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CaptchaDialog(
          store: widget.store,
          challenge: challenge,
          phone: targetPhone,
          onSendSMS: (token) {
            if (!current()) throw const ApiFailure('登录已取消');
            return widget.store.api.sendSMS(
              targetPhone,
              token,
              widget.store.headers,
            );
          },
        ),
      );
      if (!current() || outcome == null) return;
      if (outcome.error != null) {
        setState(() => error = '${outcome.error}');
        return;
      }
      final response = outcome.response!;
      resendTimer?.cancel();
      setState(() {
        requestedPhone = targetPhone;
        countdown = response.retryAfterSeconds.clamp(1, 3600);
        smsStatus = '短信验证码已发送，请注意查收';
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
      if (mounted) setState(() => requestingCode = false);
    }
  }

  Future<void> signInWithPhone() async {
    if (disabled) return;
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
    setState(() {
      signingInWith = '手机号';
      error = null;
    });
    try {
      if (!await confirmAgreement() || !mounted) return;
      await widget.store.signIn(
        phone.text,
        code.text,
        confirmRegistration: confirmRegistration,
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => signingInWith = null);
    }
  }

  Future<bool> confirmRegistration() async {
    if (!mounted) return false;
    final confirmed =
        await showAppConfirmation(
          context,
          dialogKey: const ValueKey('auth-registration-dialog'),
          barrierDismissible: false,
          title: '该账号尚未注册',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('是否创建博简账号并完成登录？'),
              const SizedBox(height: 14),
              CupertinoTextField(
                key: const ValueKey('registration-invite-code'),
                controller: inviteCode,
                placeholder: '邀请码（选填）',
                maxLength: 32,
                autocorrect: false,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 8),
              const Text(
                '填写好友邀请码，绑定手机号后好友可得 500 积分。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          cancelLabel: '暂不注册',
          cancelKey: const ValueKey('auth-registration-cancel'),
          confirmLabel: '确认注册并登录',
          confirmKey: const ValueKey('auth-registration-confirm'),
        ) ??
        false;
    widget.store.registrationInviteCode = confirmed
        ? inviteCode.text.trim()
        : '';
    return confirmed;
  }

  Future<void> legal(bool privacy) async {
    await openPage<void>(
      context,
      LegalDocumentPage(
        kind: privacy
            ? LegalDocumentKind.privacyPolicy
            : LegalDocumentKind.userAgreement,
      ),
    );
  }

  Widget alternativeLogin({
    required String keyName,
    required String label,
    required String asset,
    required VoidCallback onTap,
  }) => TextButton(
    key: ValueKey(keyName),
    onPressed: disabled ? null : onTap,
    style: TextButton.styleFrom(
      foregroundColor: context.loginInk,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ).withoutHover(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 28,
          alignment: Alignment.center,
          child: LoginAppIcon(asset: asset, size: 28),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.loginMuted)),
      ],
    ),
  );

  InputDecoration fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 15, color: context.loginMuted),
    filled: true,
    fillColor: context.colors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.loginLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.loginLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.colors.accent, width: 1.4),
    ),
  );

  Widget buildIllustration() => const SizedBox(
    height: 112,
    child: LoginIllustration(key: ValueKey('auth-illustration')),
  );

  Widget buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '欢迎使用博简',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: context.loginInk,
        ),
      ),
      const SizedBox(height: 20),
      AutofillGroup(
        child: Column(
          children: [
            TextField(
              key: const ValueKey('auth-phone'),
              controller: phone,
              enabled: !disabled,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: TextStyle(fontSize: 15, color: context.loginInk),
              decoration: fieldDecoration('请输入手机号').copyWith(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 18, right: 12),
                  child: Text(
                    '+86',
                    style: TextStyle(fontSize: 14, color: context.loginInk),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
              onChanged: (_) => setState(() {
                error = null;
                smsStatus = null;
                code.clear();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('auth-code'),
              controller: code,
              enabled: !disabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: TextStyle(fontSize: 15, color: context.loginInk),
              decoration: fieldDecoration('验证码').copyWith(
                suffixIcon: SizedBox(
                  width: 124,
                  child: TextButton(
                    key: const ValueKey('auth-request-code'),
                    onPressed: disabled || countdown > 0 ? null : requestCode,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                    ).withoutHover(),
                    child: Text(
                      requestingCode
                          ? '正在获取…'
                          : countdown > 0
                          ? '${countdown}s 后重试'
                          : '获取验证码',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              onChanged: (_) => setState(() => error = null),
              onSubmitted: (_) => signInWithPhone(),
            ),
          ],
        ),
      ),
      if (error != null || smsStatus != null) ...[
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: Text(
            error ?? smsStatus!,
            key: ValueKey(error != null ? 'auth-error' : 'auth-status'),
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
        key: const ValueKey('auth-submit'),
        onPressed: disabled ? null : signInWithPhone,
        style: loginPrimaryButtonStyle(context),
        child: Text(signingInWith == '手机号' ? '正在登录…' : '登录'),
      ),
      const SizedBox(height: 8),
      LoginConsent(
        agreed: agreed,
        onChanged: submitting ? null : changeAgreement,
        onOpenTerms: () => legal(false),
        onOpenPrivacy: () => legal(true),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(child: Divider(color: context.loginLine)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '更多登录方式',
              style: TextStyle(fontSize: 12, color: context.loginMuted),
            ),
          ),
          Expanded(child: Divider(color: context.loginLine)),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        children: [
          alternativeLogin(
            keyName: 'auth-wechat',
            label: signingInWith == '微信' ? '授权中…' : '微信登录',
            asset: 'assets/login/wechat.jpg',
            onTap: () => signIn(),
          ),
          alternativeLogin(
            keyName: 'auth-douyin',
            label: signingInWith == '抖音' ? '授权中…' : '抖音登录',
            asset: 'assets/login/douyin.jpg',
            onTap: () => signIn(douyin: true),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.loginCanvas,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 600;
          final padding = EdgeInsets.symmetric(
            horizontal: landscape ? 32 : 28,
            vertical: 24,
          );
          final contentHeight = (constraints.maxHeight - padding.vertical)
              .clamp(0.0, double.infinity)
              .toDouble();
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: landscape ? 880 : 420),
              child: SingleChildScrollView(
                padding: padding,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: landscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 4, child: buildIllustration()),
                            const SizedBox(width: 40),
                            Expanded(flex: 5, child: buildForm()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (MediaQuery.viewInsetsOf(context).bottom ==
                                0) ...[
                              buildIllustration(),
                              const SizedBox(height: 24),
                            ],
                            buildForm(),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    resendTimer?.cancel();
    inviteCode.dispose();
    phone.dispose();
    code.dispose();
    widget.store.removeListener(refreshState);
    super.dispose();
  }
}
