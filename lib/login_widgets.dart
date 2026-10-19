import 'package:flutter/material.dart';

import 'app_theme.dart';

extension LoginTheme on BuildContext {
  Color get loginCanvas => isDark ? colors.canvas : const Color(0xFFF7F7F5);
  Color get loginInk => isDark ? colors.ink : const Color(0xFF25292E);
  Color get loginLine => isDark ? colors.border : const Color(0xFFE1E3E5);
  Color get loginMuted => isDark ? colors.muted : const Color(0xFF6F747C);
  Color get loginOnPrimary => isDark ? colors.canvas : Colors.white;
}

ButtonStyle loginPrimaryButtonStyle(BuildContext context) =>
    FilledButton.styleFrom(
      backgroundColor: context.loginInk,
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
                  ? context.loginInk
                  : Colors.transparent,
            ),
            side: WidgetStateBorderSide.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.selected)
                    ? context.loginInk
                    : const Color(0xFFB7BBBF),
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
