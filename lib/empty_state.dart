import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The artwork of one kind of empty, withheld or failed page.
enum EmptyArt {
  resume('empty_resume'),
  post('empty_post'),
  draft('empty_draft'),
  saved('empty_saved'),
  search('empty_search'),
  comment('empty_comment'),
  message('empty_message'),
  profileHidden('profile_hidden'),
  loadFailed('load_failed'),
  contentGone('content_gone'),
  order('empty_order'),
  coupon('empty_coupon'),
  section('empty_section');

  const EmptyArt(this.file);
  final String file;
  String get asset => 'assets/empty_states/$file.webp';
}

/// Shared presentation of a page with nothing to list. Screen-specific artwork,
/// copy and actions belong to the caller.
class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.detail, {
    super.key,
    required this.art,
    this.compact = false,
    this.action,
  });

  /// A request that failed, with the way to try again.
  EmptyState.failed(
    this.title, {
    super.key,
    required VoidCallback? onRetry,
    String retryLabel = '重新加载',
    this.compact = false,
  }) : detail = '',
       art = EmptyArt.loadFailed,
       action = TextButton(onPressed: onRetry, child: Text(retryLabel));

  final EmptyArt art;
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
                  art.asset,
                  // The scenes are 3:2, with two figures that need the room.
                  width: small ? 144 : 216,
                  height: small ? 96 : 144,
                  fit: BoxFit.contain,
                  cacheWidth: 720,
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
