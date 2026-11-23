import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';
import 'resume_editor_typography.dart';

/// Opens a [PanelSheet]-style modal: no drag handle, transparent route
/// background so the panel draws its own rounded top.
Future<T?> showPanelSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .4),
  builder: builder,
);

/// Bottom panel with a centred title, a close button and grouped content.
class PanelSheet extends StatelessWidget {
  const PanelSheet({
    super.key,
    this.title,
    this.header,
    required this.child,
    this.closeKey,
    this.horizontalPadding = 16,
    this.backgroundColor,
  }) : assert((title == null) != (header == null));

  final String? title;
  final Widget? header;
  final Widget child;
  final Key? closeKey;
  final double horizontalPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => Material(
    color: backgroundColor ?? context.colors.inset,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .4).clamp(260, 360),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            16,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (header == null) const SizedBox(width: 48),
                  Expanded(
                    child:
                        header ??
                        Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: ResumeEditorTypography.title,
                        ),
                  ),
                  IconButton(
                    key: closeKey,
                    tooltip: '关闭',
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const AppIcon(AppIcons.close, size: 22),
                  ),
                ],
              ),
              if (header != null)
                Divider(height: 1, color: context.colors.border),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

/// White rounded card of rows separated by inset dividers.
class PanelGroup extends StatelessWidget {
  const PanelGroup({super.key, required this.children, this.outlined = false});

  final List<Widget> children;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: outlined
          ? BorderSide(color: context.colors.border)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              indent: outlined ? 16 : 54,
              endIndent: 16,
              color: context.colors.border,
            ),
          children[i],
        ],
      ],
    ),
  );
}

/// Icon + label row used inside a [PanelGroup].
class PanelAction extends StatelessWidget {
  const PanelAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final bool destructive;
  final AppIconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: destructive
          ? Theme.of(context).colorScheme.error
          : context.colors.ink,
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      shape: const RoundedRectangleBorder(),
      textStyle: ResumeEditorTypography.action,
    ).withoutHover(),
    onPressed: onPressed,
    child: Row(
      children: [
        AppIcon(
          icon,
          size: 22,
          color: destructive ? Theme.of(context).colorScheme.error : null,
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
