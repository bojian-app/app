import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Gently pulses its placeholder [child] while content loads; holds still when
/// the system asks for reduced motion.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller
        ..stop()
        ..value = 1;
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载',
    container: true,
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(
          begin: 0.45,
          end: 1.0,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// One grey placeholder bar or shape.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
  });
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.inset,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Placeholder rows for a list that has nothing to show yet.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Column(
      key: const ValueKey('list-skeleton'),
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: i.isEven ? 160 : 120, height: 16),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 90, height: 12),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
