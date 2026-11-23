import 'package:flutter/material.dart';

import 'design.dart';

/// Pill-shaped comment input shared by article and region comment sheets.
class CommentInputField extends StatelessWidget {
  const CommentInputField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.hintText,
    required this.maxLines,
    this.focusNode,
    this.enabled = true,
    this.maxLength,
    this.scrollPadding = const EdgeInsets.all(20),
    this.textInputAction,
    this.onSubmitted,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final FocusNode? focusNode;
  final bool enabled;
  final int? maxLength;
  final EdgeInsets scrollPadding;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    );
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      minLines: 1,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: dark ? context.colors.ink : const Color(0xFF24262B),
      ),
      scrollPadding: scrollPadding,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13,
          color: dark ? context.colors.muted : const Color(0xFFA7ABB3),
        ),
        counterText: maxLength == null ? null : '',
        filled: true,
        fillColor: dark ? context.colors.inset : const Color(0xFFF4F5F7),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }
}

/// Send button that enables itself once [controller] holds non-blank text.
class CommentSendButton extends StatelessWidget {
  const CommentSendButton({
    super.key,
    this.buttonKey,
    required this.controller,
    required this.sending,
    required this.onPressed,
  });

  final Key? buttonKey;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => FilledButton(
          key: buttonKey,
          onPressed: sending || value.text.trim().isEmpty ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.palette.seed,
            disabledBackgroundColor: context.isDark
                ? context.colors.inset
                : const Color(0xFFF0F1F4),
            disabledForegroundColor: context.isDark
                ? context.colors.muted
                : const Color(0xFFB3B7BE),
            minimumSize: const Size(52, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(21),
            ),
            textStyle: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ).withoutHover(),
          child: Text(sending ? '发送中' : '发送'),
        ),
      );
}

/// "展开 N 条回复 / 收起回复" link under a comment thread.
class ReplyThreadToggle extends StatelessWidget {
  const ReplyThreadToggle({
    super.key,
    required this.expanded,
    required this.replyCount,
    required this.onPressed,
  });

  final bool expanded;
  final int replyCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.isDark
          ? context.colors.muted
          : const Color(0xFF7F8897),
      overlayColor: Colors.transparent,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ).withoutHover(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 1,
          color: context.isDark
              ? context.colors.accentSoft
              : const Color(0xFFD7DADE),
        ),
        const SizedBox(width: 8),
        Text(expanded ? '收起回复' : '展开 $replyCount 条回复'),
        const SizedBox(width: 2),
        Icon(
          expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          size: 16,
        ),
      ],
    ),
  );
}
