import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_tab_bar_glass.dart';
import 'design.dart';
import 'messages_button.dart' show UnreadBadge;
import 'update_badge.dart';

/// One entry of [AppTabBar]. [key] identifies its tap target.
typedef AppTabBarItem = ({Key key, String label, AppIconData icon});

/// The floating capsule at the bottom of the home shell, solid, clear glass or
/// frosted glass as [style] says, over the page scrolling beneath it. The
/// [action] stands apart from it, a round button raised out of a notch in the
/// middle of its top edge.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.action,
    required this.onAction,
    this.style = AppTabBarStyle.solid,
    this.unread = const {},
    this.updateAt,
  });

  /// Height of the capsule.
  static const height = 60.0;
  static const sideGap = 10.0;
  static const maxWidth = 480.0;
  static const _itemWidth = 68.0;

  static const actionSize = 56.0;

  /// How far below the capsule's top edge the action's centre sits.
  static const _actionDrop = 8.0;

  /// How far the action reaches above the capsule.
  static const rise = actionSize / 2 - _actionDrop;

  /// Clear space between the action and the notch around it.
  static const _notchRadius = actionSize / 2 + 5;
  static const _notchShoulder = 10.0;
  static const _actionSlot = 76.0;

  /// The selection follows the page it belongs to.
  static const motionDuration = appPageTransitionDuration;
  static const motionCurve = appPageTransitionCurve;

  /// The destinations, split evenly to both sides of the [action].
  final List<AppTabBarItem> items;

  /// Index into [items] of the page on show.
  final int selected;
  final ValueChanged<int> onSelect;

  /// Drawn as its icon alone; its label is only read out.
  final AppTabBarItem action;
  final VoidCallback onAction;

  final AppTabBarStyle style;

  /// Unread counts shown over the [items] at these indices.
  final Map<int, int> unread;

  /// Index of the item that flags an available app update.
  final int? updateAt;

  /// Distance from the screen's bottom edge. iOS lets the capsule reach into
  /// the home indicator area, as its own tab bars do; elsewhere it clears the
  /// gesture bar or navigation buttons completely.
  static double bottomGap(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return math.max(
      sideGap,
      Theme.of(context).platform == TargetPlatform.iOS ? inset - 13 : inset + 4,
    );
  }

  /// The capsule with the notch cut from its top edge, rounded where they meet.
  static Path _capsule(Size size) {
    final centre = Offset(size.width / 2, _actionDrop);
    const reach = _notchRadius + _notchShoulder;
    const lift = _notchShoulder - _actionDrop;
    final half = math.sqrt(reach * reach - lift * lift);
    // Where a shoulder hands over to the notch's own circle.
    Offset joint(double side) =>
        centre + Offset(side * half, lift) * (_notchRadius / reach);
    final left = joint(-1), right = joint(1);
    final notch = Path()
      ..moveTo(centre.dx - half, -4)
      ..lineTo(centre.dx - half, 0)
      ..arcToPoint(left, radius: const Radius.circular(_notchShoulder))
      ..arcToPoint(
        right,
        radius: const Radius.circular(_notchRadius),
        clockwise: false,
      )
      ..arcToPoint(
        Offset(centre.dx + half, 0),
        radius: const Radius.circular(_notchShoulder),
      )
      ..lineTo(centre.dx + half, -4)
      ..close();
    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      ),
      notch,
    );
  }

  static Path _circle(Size size) => Path()..addOval(Offset.zero & size);

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final foreground = dark ? Colors.white : context.colors.ink;
    final safe = MediaQuery.paddingOf(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : motionDuration;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sideGap + safe.left,
        0,
        sideGap + safe.right,
        bottomGap(context),
      ),
      child: Align(
        heightFactor: 1,
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          // The strip beside the action lets touches through to the page.
          child: SizedBox(
            width: double.infinity,
            height: rise + height,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height,
                  // Taps between entries must not reach the page underneath.
                  child: GestureDetector(
                    key: const ValueKey('app-tab-bar'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: _Pane(
                      outline: _capsule,
                      style: style,
                      notch: (
                        centre: const Offset(0, _actionDrop - height / 2),
                        radius: _notchRadius,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = math.min(
                            _itemWidth,
                            (constraints.maxWidth - 12 - _actionSlot) /
                                items.length,
                          );
                          final start =
                              (constraints.maxWidth -
                                  width * items.length -
                                  _actionSlot) /
                              2;
                          double left(int index) =>
                              start +
                              index * width +
                              (index < items.length ~/ 2 ? 0 : _actionSlot);
                          return Stack(
                            children: [
                              AnimatedPositioned(
                                key: const ValueKey('app-tab-selection'),
                                duration: duration,
                                curve: motionCurve,
                                left: left(selected) - 2,
                                top: 5,
                                width: width + 4,
                                height: height - 10,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: context.colors.accent.withValues(
                                      alpha: dark ? .16 : .09,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                              ),
                              for (final (index, item) in items.indexed)
                                Positioned(
                                  left: left(index),
                                  top: 0,
                                  bottom: 0,
                                  width: width,
                                  child: _TabButton(
                                    key: item.key,
                                    item: item,
                                    unread: unread[index] ?? 0,
                                    flagsUpdate: index == updateAt,
                                    selected: index == selected,
                                    color: foreground,
                                    halo: style != AppTabBarStyle.solid,
                                    onTap: () => onSelect(index),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: actionSize,
                  child: Center(
                    child: SizedBox.square(
                      dimension: actionSize,
                      child: Semantics(
                        button: true,
                        label: action.label,
                        excludeSemantics: true,
                        onTap: onAction,
                        child: GestureDetector(
                          key: action.key,
                          behavior: HitTestBehavior.opaque,
                          onTap: onAction,
                          child: _Pane(
                            outline: _circle,
                            style: style,
                            raised: true,
                            child: Center(
                              child: AppIcon(
                                action.icon,
                                size: 30,
                                color: foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.item,
    required this.selected,
    required this.color,
    required this.onTap,
    this.unread = 0,
    this.flagsUpdate = false,
    this.halo = false,
  });
  final AppTabBarItem item;
  final int unread;
  final bool flagsUpdate;
  final bool halo;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Both tones come from the theme's accent: the selected entry is drawn in
    // it outright, the others keep their outline in [color] over a paler fill.
    final dark = context.isDark;
    final accent = context.colors.accent;
    final ink = selected ? accent : color;
    final fill = accent.withValues(
      alpha: selected ? (dark ? .42 : .28) : (dark ? .32 : .22),
    );
    final icon = AppIcon(item.icon, size: 23, color: ink, secondaryColor: fill);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      value: unread > 0 ? '$unread条未读消息' : null,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (flagsUpdate) UpdateBadge(child: icon) else icon,
                  if (unread > 0)
                    PositionedDirectional(
                      top: -8,
                      end: -13,
                      child: UnreadBadge(unread),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 15,
                // The capsule has a fixed height, so large text shrinks to fit.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.2),
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      letterSpacing: .1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: ink,
                      // Glass lets the page through; a soft halo keeps the
                      // label apart from whatever lies beneath it.
                      shadows: halo
                          ? [
                              Shadow(
                                color: dark
                                    ? Colors.black.withValues(alpha: .45)
                                    : Colors.white.withValues(alpha: .85),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Outline = Path Function(Size size);

/// One pane of the bar along one [outline], floating on its shadow. A [raised]
/// one floats higher.
class _Pane extends StatelessWidget {
  const _Pane({
    required this.outline,
    required this.style,
    required this.child,
    this.notch,
    this.raised = false,
  });
  final _Outline outline;
  final AppTabBarStyle style;
  final bool raised;

  /// What the glass has to know about a notch in its [outline].
  final GlassNotch? notch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    if (style != AppTabBarStyle.solid) {
      return GlassTabPane(
        outline: outline,
        dark: dark,
        frosted: style == AppTabBarStyle.frosted,
        notch: notch,
        raised: raised,
        child: child,
      );
    }
    // White on the light page, where the shadow sets it apart; on the dark one,
    // where shadows hardly show, a tone lighter than the page.
    final fill = dark ? context.colors.inset : context.colors.surface;
    return CustomPaint(
      painter: _SolidPainter(outline, fill, dark, raised),
      child: child,
    );
  }
}

class _SolidPainter extends CustomPainter {
  const _SolidPainter(this.outline, this.fill, this.dark, this.raised);
  final _Outline outline;
  final Color fill;
  final bool dark, raised;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = outline(size);
    void shadow(double alpha, double blur, double drop) => canvas.drawPath(
      shape.shift(Offset(0, drop)),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? alpha * 3 : alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    // A tight shadow draws the edge, a wide one lifts the pane off the page.
    shadow(.06, 2, 1);
    shadow(raised ? .14 : .10, raised ? 10 : 12, raised ? 5 : 4);
    canvas.drawPath(shape, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_SolidPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      dark != oldDelegate.dark ||
      raised != oldDelegate.raised ||
      outline != oldDelegate.outline;
}
