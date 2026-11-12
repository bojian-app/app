import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

extension LoginTheme on BuildContext {
  Color get loginCanvas => colors.canvas;
  Color get loginInk => colors.ink;
  Color get loginLine => colors.border;
  Color get loginMuted => colors.muted;
  Color get loginOnPrimary => Theme.of(this).colorScheme.onPrimary;
}

ButtonStyle loginPrimaryButtonStyle(BuildContext context) =>
    FilledButton.styleFrom(
      backgroundColor: context.colors.accent,
      foregroundColor: context.loginOnPrimary,
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ).withoutHover();

class LoginAppIcon extends StatelessWidget {
  const LoginAppIcon({super.key, required this.asset, this.size = 24});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .23),
    child: Image.asset(
      asset,
      width: size,
      height: size,
      cacheWidth: 192,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    ),
  );
}

class LoginConsent extends StatelessWidget {
  const LoginConsent({
    super.key,
    required this.agreed,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    this.keyPrefix = 'auth',
  });

  final bool agreed;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Checkbox(
            key: ValueKey('$keyPrefix-consent'),
            value: agreed,
            onChanged: onChanged == null
                ? null
                : (value) => onChanged!(value ?? false),
            semanticLabel: '同意用户协议和隐私政策',
            shape: const CircleBorder(),
            checkColor: context.loginOnPrimary,
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? context.colors.accent
                  : Colors.transparent,
            ),
            side: WidgetStateBorderSide.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.selected)
                    ? context.colors.accent
                    : context.colors.muted,
                width: 1.2,
              ),
            ),
          ),
        ),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                checked: agreed,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(!agreed),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '我已阅读并同意',
                      style: TextStyle(fontSize: 11, color: context.loginMuted),
                    ),
                  ),
                ),
              ),
              TextButton(
                key: ValueKey('$keyPrefix-user-agreement'),
                onPressed: onOpenTerms,
                style: TextButton.styleFrom(
                  foregroundColor: context.loginInk,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  textStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ).withoutHover(),
                child: const Text('用户协议', style: TextStyle(fontSize: 11)),
              ),
              Text(
                '及',
                style: TextStyle(fontSize: 11, color: context.loginMuted),
              ),
              TextButton(
                key: ValueKey('$keyPrefix-privacy-policy'),
                onPressed: onOpenPrivacy,
                style: TextButton.styleFrom(
                  foregroundColor: context.loginInk,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  textStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ).withoutHover(),
                child: const Text('隐私政策', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

InputDecoration loginFieldDecoration(BuildContext context, String hint) =>
    InputDecoration(
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

/// Phone and SMS-code inputs shared by every login step that proves a phone.
class LoginPhoneCodeFields extends StatelessWidget {
  const LoginPhoneCodeFields({
    super.key,
    required this.phone,
    required this.code,
    required this.enabled,
    required this.requesting,
    required this.countdown,
    required this.onRequestCode,
    required this.onPhoneChanged,
    required this.onCodeChanged,
    required this.onSubmitted,
    this.keyPrefix = 'auth',
  });

  final TextEditingController phone;
  final TextEditingController code;
  final bool enabled;
  final bool requesting;
  final int countdown;
  final VoidCallback onRequestCode;
  final VoidCallback onPhoneChanged;
  final VoidCallback onCodeChanged;
  final VoidCallback onSubmitted;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: Column(
      children: [
        TextField(
          key: ValueKey('$keyPrefix-phone'),
          controller: phone,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          style: TextStyle(fontSize: 15, color: context.loginInk),
          decoration: loginFieldDecoration(context, '请输入手机号').copyWith(
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
          onChanged: (_) => onPhoneChanged(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: ValueKey('$keyPrefix-code'),
          controller: code,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: TextStyle(fontSize: 15, color: context.loginInk),
          decoration: loginFieldDecoration(context, '验证码').copyWith(
            suffixIcon: SizedBox(
              width: 124,
              child: TextButton(
                key: ValueKey('$keyPrefix-request-code'),
                onPressed: !enabled || countdown > 0 ? null : onRequestCode,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                ).withoutHover(),
                child: Text(
                  requesting
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
          onChanged: (_) => onCodeChanged(),
          onSubmitted: (_) => onSubmitted(),
        ),
      ],
    ),
  );
}
