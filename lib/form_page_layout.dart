import 'package:flutter/material.dart';

import 'design.dart';

/// Scrollable form content with a full-width primary action pinned below it.
class FormPageLayout extends StatelessWidget {
  const FormPageLayout({
    super.key,
    required this.children,
    required this.action,
    this.contentPadding = const EdgeInsets.fromLTRB(
      appPageHorizontalPadding,
      24,
      appPageHorizontalPadding,
      20,
    ),
  });

  final List<Widget> children;
  final Widget action;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: contentPadding,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: children,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                appPageHorizontalPadding,
                12,
                appPageHorizontalPadding,
                20,
              ),
              child: action,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Full-width 48pt primary button used at the bottom of form pages.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: buttonKey,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: context.colors.accentSoft,
        disabledForegroundColor: context.colors.accent.withValues(alpha: .5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}
