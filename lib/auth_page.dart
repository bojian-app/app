import 'dart:async';

import 'agreement_dialog.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'captcha_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'design.dart';

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

  final phone = TextEditingController();
  final code = TextEditingController();
  bool agreed = false;
  String? error;
  String? requestedPhone;
  int countdown = 0;
  Timer? timer;

  bool get validPhone => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text);

  bool requesting = false;
  bool submitting = false;

  void changeAgreement(bool? value) => setState(() {
    agreed = value ?? false;
    error = null;
  });

  Future<bool> confirmAgreement() async {
    if (agreed) return true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .36),
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

  Future<void> requestCode() async {
    if (requesting || submitting) return;
    if (!validPhone) {
      setState(() => error = '请输入正确的 11 位手机号');
      return;
    }
    dismissKeyboard();
    final targetPhone = phone.text;
    setState(() {
      requesting = true;
      error = null;
    });
    try {
      if (!await confirmAgreement()) return;
      await widget.store.initialize();
      final challenge = await widget.store.api.createCaptcha(
        widget.store.headers,
      );
      if (!mounted) return;
      final seconds = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CaptchaDialog(
          store: widget.store,
          challenge: challenge,
          phone: targetPhone,
        ),
      );
      if (!mounted || seconds == null) return;
      timer?.cancel();
      setState(() {
        requestedPhone = targetPhone;
        countdown = seconds.clamp(1, 3600);
      });
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => countdown--);
        if (countdown == 0) t.cancel();
      });
      toast(context, '验证码已发送，请查看短信');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  Future<void> submit() async {
    String? message;
    if (!validPhone) {
      message = '请输入正确的 11 位手机号';
    } else if (!agreed) {
      message = '请先阅读并同意用户协议和隐私政策';
    } else if (code.text.length != 6) {
      message = '请输入 6 位短信验证码';
    }
    if (message != null) {
      setState(() => error = message);
      return;
    }
    dismissKeyboard();
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.store.signIn(phone.text, code.text);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
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

  final formKey = GlobalKey();

  Widget buildBrand({required bool landscape}) => Column(
    key: const ValueKey('auth-brand'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: landscape ? 72 : 84,
        height: landscape ? 72 : 84,
        padding: const EdgeInsets.all(12),
        child: Image.asset('assets/branding/app_icon.png'),
      ),
      SizedBox(height: landscape ? 16 : 24),
      Text(
        '欢迎回到博简',
        style: TextStyle(
          fontSize: landscape ? 24 : 27,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        '把繁杂，变简单。\n让每一份努力，都有更好的表达。',
        style: TextStyle(fontSize: 13, height: 1.8, color: muted),
      ),
    ],
  );

  Widget buildForm() => AutofillGroup(
    key: formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('auth-phone'),
          controller: phone,
          enabled: !requesting && !submitting,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入 11 位手机号',
            prefixIcon: Padding(
              padding: EdgeInsets.all(16),
              child: Text('+86', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('auth-code'),
          controller: code,
          enabled: !submitting,
          autofillHints: const [AutofillHints.oneTimeCode],
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => dismissKeyboard(),
          decoration: InputDecoration(
            labelText: '验证码',
            hintText: '请输入 6 位验证码',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                key: const ValueKey('auth-request-code'),
                onPressed: countdown > 0 || requesting || submitting
                    ? null
                    : requestCode,
                child: Text(
                  requesting
                      ? '正在获取…'
                      : countdown > 0
                      ? '${countdown}s 后重试'
                      : '获取验证码',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            key: const ValueKey('auth-error'),
            style: const TextStyle(color: Color(0xFFC74D4D), fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 44,
              child: Checkbox(
                key: const ValueKey('auth-consent'),
                value: agreed,
                onChanged: changeAgreement,
                semanticLabel: '同意用户协议和隐私政策',
                shape: const CircleBorder(),
                checkColor: Colors.white,
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? blue
                      : Colors.transparent,
                ),
                side: WidgetStateBorderSide.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.selected)
                        ? blue
                        : const Color(0xFFBCC4D1),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    checked: agreed,
                    child: InkWell(
                      onTap: () => changeAgreement(!agreed),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '我已阅读并同意',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('auth-user-agreement'),
                    onPressed: () => legal(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                    ),
                    child: const Text('用户协议', style: TextStyle(fontSize: 11)),
                  ),
                  const Text('及', style: TextStyle(fontSize: 11, color: muted)),
                  TextButton(
                    key: const ValueKey('auth-privacy-policy'),
                    onPressed: () => legal(true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                    ),
                    child: const Text('隐私政策', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('auth-submit'),
            onPressed: submitting || requesting || widget.store.restoring
                ? null
                : submit,
            child: Text(submitting ? '正在验证…' : '登录博简'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 600;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: landscape ? 960 : 480),
              child: SingleChildScrollView(
                padding: landscape
                    ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
                    : const EdgeInsets.fromLTRB(28, 12, 28, 28),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: landscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 4, child: buildBrand(landscape: true)),
                          const SizedBox(width: 40),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const DismissKeyboardButton(),
                                buildForm(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DismissKeyboardButton(),
                          const SizedBox(height: 24),
                          buildBrand(landscape: false),
                          const SizedBox(height: 32),
                          buildForm(),
                        ],
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
    widget.store.removeListener(refreshState);
    timer?.cancel();
    phone.dispose();
    code.dispose();
    super.dispose();
  }
}
