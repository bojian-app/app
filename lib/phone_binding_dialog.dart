import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'captcha_dialog.dart';
import 'confirmation_dialog.dart';
import 'design.dart';

final _activeBindingDialogs = Expando<Future<bool?>>();

Future<bool?> showPhoneBindingDialog(
  BuildContext context, {
  required AppStore store,
}) {
  final active = _activeBindingDialogs[store];
  if (active != null) return active;
  final result = showAppDialog<bool>(
    context,
    builder: (_) => PhoneBindingDialog(store: store),
  ).whenComplete(() => _activeBindingDialogs[store] = null);
  _activeBindingDialogs[store] = result;
  return result;
}

class PhoneBindingDialog extends StatefulWidget {
  const PhoneBindingDialog({super.key, required this.store});
  final AppStore store;

  @override
  State<PhoneBindingDialog> createState() => _PhoneBindingDialogState();
}

class _PhoneBindingDialogState extends State<PhoneBindingDialog> {
  final phone = TextEditingController();
  final code = TextEditingController();
  late final int accountEpoch;
  Timer? timer;
  int countdown = 0;
  String? requestedPhone;
  String? error;
  String? status;
  bool requesting = false;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
  }

  bool get current =>
      mounted &&
      widget.store.isAuthenticated &&
      widget.store.epoch == accountEpoch;
  bool get busy => requesting || submitting;
  bool get validPhone => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text);

  Future<void> requestCode() async {
    if (busy || countdown > 0 || !current) return;
    if (!validPhone) {
      setState(() => error = '请输入正确的 11 位手机号');
      return;
    }
    dismissKeyboard();
    final targetPhone = phone.text;
    setState(() {
      requesting = true;
      error = null;
      status = null;
    });
    try {
      final challenge = await widget.store.api.createCaptcha(
        widget.store.headers,
      );
      if (!mounted || !current) return;
      final outcome = await showDialog<SmsRequestOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CaptchaDialog(
          store: widget.store,
          challenge: challenge,
          phone: targetPhone,
          onSendSMS: (token) {
            if (!current) throw const ApiFailure('账号已切换，请重试');
            return widget.store.sendPhoneBindingCode(targetPhone, token);
          },
        ),
      );
      if (!current || outcome == null) return;
      if (outcome.error != null) {
        setState(() => error = '${outcome.error}');
        return;
      }
      final response = outcome.response!;
      timer?.cancel();
      setState(() {
        requestedPhone = targetPhone;
        countdown = response.retryAfterSeconds.clamp(1, 3600);
        status = response.deliveryStatus == 'DELIVERED'
            ? '验证码已发送，请查看短信'
            : '发送请求已提交，请稍后查看短信';
      });
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!current) {
          timer.cancel();
          return;
        }
        setState(() => countdown--);
        if (countdown == 0) timer.cancel();
      });
    } catch (e) {
      if (current) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  Future<void> submit() async {
    if (busy || !current) return;
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
      submitting = true;
      error = null;
    });
    try {
      await widget.store.bindPhone(phone.text, code.text);
      if (mounted && current) Navigator.pop(context, true);
    } catch (e) {
      if (current) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    final fieldDecoration = BoxDecoration(
      color: CupertinoColors.systemBackground
          .resolveFrom(context)
          .withValues(alpha: 0.55),
      border: Border.all(color: separator, width: 0.5),
      borderRadius: BorderRadius.circular(6),
    );
    const fieldPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 14);
    const fieldStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.25,
    );
    final placeholderStyle = fieldStyle.copyWith(
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return PopScope(
      canPop: !busy,
      child: AppConfirmationDialog(
        key: const ValueKey('phone-binding-dialog'),
        title: '绑定手机号',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              key: const ValueKey('phone-binding-phone'),
              controller: phone,
              enabled: !busy,
              placeholder: '请输入手机号',
              placeholderStyle: placeholderStyle,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: fieldDecoration,
              padding: fieldPadding,
              style: fieldStyle,
              onChanged: (_) => setState(() {
                status = null;
                error = null;
              }),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              key: const ValueKey('phone-binding-code'),
              controller: code,
              enabled: !busy,
              placeholder: '验证码',
              placeholderStyle: placeholderStyle,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: fieldDecoration,
              padding: fieldPadding,
              style: fieldStyle,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 0.5, height: 20, color: separator),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: CupertinoButton(
                        key: const ValueKey('phone-binding-request-code'),
                        onPressed: busy || countdown > 0 ? null : requestCode,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          requesting
                              ? '正在获取…'
                              : countdown > 0
                              ? '${countdown}s 后重试'
                              : '获取验证码',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => dismissKeyboard(),
            ),
            if (error != null || status != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  error ?? status!,
                  key: ValueKey(
                    error != null
                        ? 'phone-binding-error'
                        : 'phone-binding-status',
                  ),
                  style: TextStyle(
                    color: error != null
                        ? CupertinoColors.systemRed
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ],
        ),
        cancelLabel: '暂时跳过',
        cancelKey: const ValueKey('phone-binding-skip'),
        confirmLabel: submitting ? '绑定中…' : '绑定',
        confirmKey: const ValueKey('phone-binding-confirm'),
        onCancel: busy ? null : () => Navigator.pop(context, false),
        onConfirm: busy ? null : submit,
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    code.dispose();
    super.dispose();
  }
}
