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
                      return CustomPaint(
                        painter: _ReactionHalo(
                          progress: _motion.value,
                          color: tint,
                          like: like,
                          enabled: widget.active,
                        ),
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              !like && widget.active ? -3 * pulse : 0,
                            ),
                            child: Transform.scale(
                              scale: scale,
                              child: AppIcon(
                                like
                                    ? AppIcons.like
                                    : widget.active
                                    ? AppIcons.bookmarked
                                    : AppIcons.bookmark,
                                size: iconSize,
                                color: color,
                              ),
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

class _ReactionHalo extends CustomPainter {
  const _ReactionHalo({
    required this.progress,
    required this.color,
    required this.like,
    required this.enabled,
  });
  final double progress;
  final Color color;
  final bool like, enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      13,
      Paint()..color = color.withValues(alpha: .08),
    );
    if (!like || progress <= 0 || progress >= 1) return;
    final paint = Paint()..color = color.withValues(alpha: .5 * (1 - progress));
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      final radius = 10 + 8 * Curves.easeOut.transform(progress);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        1.5 * (1 - progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ReactionHalo old) =>
      progress != old.progress ||
      enabled != old.enabled ||
      color != old.color ||
      like != old.like;
}
