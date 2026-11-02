import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared empty-content presentation. Loading and request failures are separate
/// states; screen-specific copy and actions belong to the caller.
class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.detail, {
    super.key,
    this.compact = false,
    this.action,
  });

  static const illustrationAsset = 'assets/empty_states/cat_detective.webp';

  final String title, detail;
  final bool compact;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final small =
          compact ||
          (constraints.hasBoundedHeight && constraints.maxHeight < 280);
      final content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: small ? 16 : 32,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  illustrationAsset,
                  width: small ? 104 : 156,
                  height: small ? 84 : 126,
                  fit: BoxFit.contain,
                  cacheWidth: 468,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.ink,
                    fontSize: small ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 12),
                  Center(child: action),
                ],
              ],
            ),
          ),
        ),
      );
      return constraints.hasBoundedHeight
          ? Center(child: SingleChildScrollView(child: content))
          : content;
    },
  );
}
