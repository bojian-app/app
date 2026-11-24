import 'dart:async';

import 'agreement_dialog.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'confirmation_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoTextField;

import 'app_store.dart';
import 'app_environment.dart';
import 'design.dart';
import 'sms_code_flow.dart';
import 'login_widgets.dart';
import 'login_illustration.dart';
import 'api/bojian_api.dart';
import 'api/generated/auth.pb.dart' as auth;
import 'login_phone_binding_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SmsCodeFlow<AuthPage> {
  @override
  AppStore get smsStore => widget.store;

  @override
  void initState() {
    super.initState();
    widget.store.confirmDeletionCancel = confirmDeletionCancel;
    widget.store.addListener(refreshState);
  }

  void refreshState() {
    if (mounted) setState(() {});
  }

  @override
  final phone = TextEditingController(text: AppEnvironment.defaultTestPhone);
  @override
  final code = TextEditingController();
  bool agreed = false;
  String? signingInWith;
  bool get submitting => signingInWith != null || requesting;
  bool get disabled => submitting || widget.store.restoring;
  @override
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
      Future<({auth.LoginResponse response, String phone})?> bindPhone(
        String token,
      ) async {
        if (!mounted) return null;
        return openPage(
          context,
          LoginPhoneBindingPage(
            store: widget.store,
            token: token,
            provider: provider,
          ),
        );
      }

      if (douyin) {
        await widget.store.signInWithDouyin(
          confirmRegistration: confirmRegistration,
          bindPhone: bindPhone,
        );
      } else {
        await widget.store.signInWithWeChat(
          confirmRegistration: confirmRegistration,
          bindPhone: bindPhone,
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
    final version = widget.store.epoch;
    bool current() =>
        mounted &&
        widget.store.epoch == version &&
        !widget.store.isAuthenticated;
    await sendSmsCode(
      current: current,
      beforeSend: confirmAgreement,
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

  Future<void> signInWithPhone() async {
    if (disabled) return;
    final message = smsSubmitError;
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

  Future<bool> confirmDeletionCancel(DateTime? executeAfter) async {
    if (!mounted) return false;
    final d = executeAfter?.toLocal();
    final when = d == null ? '' : '（原定 ${d.year}年${d.month}月${d.day}日 执行）';
    return await showAppConfirmation(
          context,
          barrierDismissible: false,
          title: '账号正在注销冷静期',
          content: Text('该账号已申请注销$when。继续登录将终止注销，账号和数据会被完整保留；不想保留请返回。'),
          cancelLabel: '返回',
          confirmLabel: '终止注销并登录',
        ) ??
        false;
  }

  Future<bool> confirmRegistration() async {
    if (!mounted) return false;
    final confirmed =
        await showAppConfirmation(
          context,
          dialogKey: const ValueKey('auth-registration-dialog'),
          barrierDismissible: false,
          title: '该账号尚未注册',
          content: const Text('是否创建最优简账号并完成登录？'),
          cancelLabel: '暂不注册',
          cancelKey: const ValueKey('auth-registration-cancel'),
          confirmLabel: '确认注册并登录',
          confirmKey: const ValueKey('auth-registration-confirm'),
        ) ??
        false;
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

  Widget buildIllustration() => const SizedBox(
    height: 112,
    child: LoginIllustration(key: ValueKey('auth-illustration')),
  );

  Widget buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '欢迎使用最优简',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: context.loginInk,
        ),
      ),
      const SizedBox(height: 20),
      LoginPhoneCodeFields(
        phone: phone,
        code: code,
        enabled: !disabled,
        requesting: requesting,
        countdown: countdown,
        onRequestCode: requestCode,
        onPhoneChanged: () => setState(() {
          error = null;
          status = null;
          code.clear();
        }),
        onCodeChanged: () => setState(() => error = null),
        onSubmitted: signInWithPhone,
      ),
      if (error != null || status != null) ...[
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: Text(
            error ?? status!,
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
            horizontal: appPageHorizontalPadding,
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
    if (widget.store.confirmDeletionCancel == confirmDeletionCancel) {
      widget.store.confirmDeletionCancel = null;
    }
    phone.dispose();
    code.dispose();
    widget.store.removeListener(refreshState);
    super.dispose();
  }
}
