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
    this.softDisabled = true,
  });

  final Key? buttonKey;

  /// Disabled state uses pale accent colours instead of the theme's grey.
  final bool softDisabled;
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
        disabledBackgroundColor: softDisabled
            ? context.colors.accentSoft
            : null,
        disabledForegroundColor: softDisabled
            ? context.colors.accent.withValues(alpha: .5)
            : null,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

/// Bar pinned under page content: white, top hairline, safe-area aware and
/// centred to [maxWidth].
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border(top: BorderSide(color: context.colors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              appPageHorizontalPadding,
              12,
              appPageHorizontalPadding,
              12,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
