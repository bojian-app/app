import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

/// Shared page navigation layout. Pages supply content and action behavior.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.titleSpacing,
    this.backgroundColor,
    this.foregroundColor,
  });

  static const titleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  final Widget? title, leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final double? titleSpacing;
  final Color? backgroundColor, foregroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? context.colors.ink;
    final style = titleStyle.copyWith(color: foreground);
    final hasLeading =
        leading != null ||
        (automaticallyImplyLeading &&
            ((Scaffold.maybeOf(context)?.hasDrawer ?? false) ||
                (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)));
    return ActionIconTheme(
      data: ActionIconThemeData(
        backButtonIconBuilder: (_) => const AppIcon(AppIcons.back, size: 22),
        closeButtonIconBuilder: (_) => const AppIcon(AppIcons.close, size: 22),
      ),
      child: AppBar(
        title: title == null
            ? null
            : DefaultTextStyle(
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title!,
              ),
        leading: leading,
        actions: actions,
        bottom: bottom,
        automaticallyImplyLeading: automaticallyImplyLeading,
        centerTitle: false,
        titleSpacing: titleSpacing ?? (hasLeading ? 0 : 16),
        toolbarHeight: kToolbarHeight,
        leadingWidth: 56,
        titleTextStyle: style,
        iconTheme: IconThemeData(color: foreground, size: 22),
        backgroundColor: backgroundColor ?? context.colors.surface,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
