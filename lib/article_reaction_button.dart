import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'design.dart';

enum ArticleReaction { like, bookmark }

/// One short, localized animation. Network requests never add a spinner.
class ArticleReactionButton extends StatefulWidget {
  const ArticleReactionButton({
    super.key,
    required this.reaction,
    required this.active,
    required this.onTap,
    this.count,
    this.compact = false,
  });
  final ArticleReaction reaction;
  final bool active;
  final VoidCallback? onTap;
  final int? count;
  final bool compact;

  @override
  State<ArticleReactionButton> createState() => _ArticleReactionButtonState();
}

class _ArticleReactionButtonState extends State<ArticleReactionButton>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );

  @override
  void didUpdateWidget(ArticleReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = 1;
      } else {
        _motion.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final like = widget.reaction == ArticleReaction.like;
    final tint = like ? const Color(0xFFE66B7F) : const Color(0xFFCA963A);
    final color = widget.active ? tint : context.colors.muted;
    final name = like ? '点赞' : '收藏';
    final label = widget.active ? '取消$name' : name;
    final iconSize = widget.compact ? 18.0 : 22.0;
    return Semantics(
      button: true,
      toggled: widget.active,
      label: '$label${widget.count == null ? '' : '，${widget.count}'}',
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashFactory: NoSplash.splashFactory,
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 36,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) {
                      final pulse = math.sin(_motion.value * math.pi);
                      final scale = widget.active
                          ? 1 + .2 * pulse
                          : 1 - .1 * pulse;
                      return Center(
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            !like && widget.active ? -3 * pulse : 0,
                          ),
                          child: Transform.scale(
                            scale: scale,
                            child: AppIcon(
                              switch ((widget.reaction, widget.active)) {
                                (ArticleReaction.like, false) => AppIcons.like,
                                (ArticleReaction.like, true) => AppIcons.liked,
                                (ArticleReaction.bookmark, false) =>
                                  AppIcons.bookmark,
                                (ArticleReaction.bookmark, true) =>
                                  AppIcons.bookmarked,
                              },
                              size: iconSize,
                              color: color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.count != null)
                  ExcludeSemantics(
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, .25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '${widget.count}',
                        key: ValueKey(widget.count),
                        style: TextStyle(
                          fontSize: widget.compact ? 11 : 12,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                if (widget.count != null) const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
