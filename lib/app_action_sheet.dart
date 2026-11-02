import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

Future<String?> showAppActionSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: context.colors.surface,
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: builder,
);

class AppSheetAction {
  const AppSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.materialIcon,
    this.key,
    this.semanticLabel,
    this.destructive = false,
    this.enabled = true,
  }) : assert((icon == null) != (materialIcon == null));

  final String value, label;
  final AppIconData? icon;
  final IconData? materialIcon;
  final Key? key;
  final String? semanticLabel;
  final bool destructive;
  final bool enabled;
}

/// Shared design for every three-dot action menu.
class AppActionSheet extends StatelessWidget {
  const AppActionSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.cancelKey,
    this.onHeaderTap,
  });

  final String title, subtitle;
  final List<AppSheetAction> actions;
  final Key? cancelKey;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onHeaderTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.colors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onHeaderTap != null) ...[
                      const SizedBox(width: 12),
                      AppIcon(
                        AppIcons.forward,
                        size: 20,
                        color: context.colors.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: context.colors.border,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final action in actions) _action(context, action),
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: context.colors.canvas,
              child: const SizedBox(height: 8, width: double.infinity),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: cancelKey,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: context.colors.ink,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _action(BuildContext context, AppSheetAction action) {
    final color = action.destructive ? Colors.redAccent : context.colors.ink;
    final VoidCallback? select = action.enabled
        ? () => Navigator.pop(context, action.value)
        : null;
    return Semantics(
      label: action.semanticLabel ?? action.label,
      button: true,
      enabled: action.enabled,
      excludeSemantics: true,
      onTap: select,
      child: InkWell(
        key: action.key,
        onTap: select,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: action.destructive
                      ? Colors.redAccent.withValues(alpha: .07)
                      : context.colors.inset,
                ),
                child: Center(
                  child: action.icon != null
                      ? AppIcon(action.icon!, size: 20, color: color)
                      : Icon(action.materialIcon, size: 20, color: color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
