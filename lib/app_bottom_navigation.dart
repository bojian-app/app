import 'package:flutter/material.dart';

import 'navigation_icon.dart';
import 'design.dart';

/// Four persistent tabs.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _destinations = ['发现', '模版市场', '积分', '我的'];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Material(
      color: context.colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    for (var index = 0; index < _destinations.length; index++)
                      Expanded(child: _destination(index, duration)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(int index, Duration duration) {
    final destination = _destinations[index];
    final active = selectedIndex == index;
    const inactiveColor = Color(0xFF9AA3AF);
    return Semantics(
      selected: active,
      button: true,
      label: destination,
      onTap: () => onSelected(index),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('nav-$index'),
        borderRadius: BorderRadius.circular(14),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        onTap: () => onSelected(index),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: active ? 1 : 0, end: active ? 1 : 0),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            final foreground = Color.lerp(
              context.isDark ? context.colors.muted : inactiveColor,
              context.colors.accent,
              progress,
            )!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: ValueKey('nav-icon-surface-$index'),
                    width: 50,
                    height: 32,
                    child: Center(
                      child: NavigationIcon(
                        index: index,
                        progress: progress,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(11) * 1.3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: Text(
                        destination,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Color.lerp(
                            context.isDark
                                ? context.colors.muted
                                : const Color(0xFF697586),
                            context.colors.accent,
                            progress,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
