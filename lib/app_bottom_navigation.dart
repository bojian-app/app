import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

/// Four persistent tabs. Company benefits are opened from Discovery.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;

  static const _destinations = [
    (label: '发现', icon: AppIcons.discover),
    (label: '简历', icon: AppIcons.resume),
    (label: '消息', icon: AppIcons.messages),
    (label: '我的', icon: AppIcons.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: borderColor)),
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
    final hasBadge = index == 2 && unreadCount > 0;
    const inactiveColor = Color(0xFF697586);
    return Semantics(
      selected: active,
      button: true,
      label: destination.label,
      value: hasBadge ? '$unreadCount条未读消息' : null,
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
            final foreground = Color.lerp(inactiveColor, blue, progress)!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        key: ValueKey('nav-icon-surface-$index'),
                        width: 50,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF)
                              .withValues(alpha: progress),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AppIcon(
                          destination.icon,
                          size: 23,
                          color: foreground,
                        ),
                      ),
                      if (hasBadge)
                        PositionedDirectional(
                          end: 1,
                          top: -3,
                          child: Container(
                            key: const ValueKey('nav-unread-badge'),
                            constraints: const BoxConstraints(minWidth: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCC4939),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              maxLines: 1,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontSize: 9,
                                height: 1.2,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: foreground,
                      fontWeight: FontWeight.w600,
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
