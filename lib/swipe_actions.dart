import 'package:flutter/material.dart';

class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.key,
  });
  final String label;
  final Color color;
  final Future<void> Function() onTap;
  final Key? key;
}

/// Swipe left to reveal [actions] behind the row, like a mail list. Only one
/// row stays open at a time; tapping an action closes the row first.
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.actions,
    required this.child,
    this.actionWidth = 76,
  });
  final List<SwipeAction> actions;
  final Widget child;
  final double actionWidth;
  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  static final _open = ValueNotifier<_SwipeActionsState?>(null);
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool busy = false;

  double get extent => widget.actionWidth * widget.actions.length;

  @override
  void initState() {
    super.initState();
    _open.addListener(_closeIfOther);
  }

  void _closeIfOther() {
    if (_open.value != this && controller.value > 0) controller.reverse();
  }

  @override
  void dispose() {
    _open.removeListener(_closeIfOther);
    if (_open.value == this) _open.value = null;
    controller.dispose();
    super.dispose();
  }

  void close() {
    controller.reverse();
    if (_open.value == this) _open.value = null;
  }

  void _settle(double velocity) {
    if (velocity < -300 || (velocity <= 300 && controller.value > .5)) {
      controller.forward();
      _open.value = this;
    } else {
      close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        if (_open.value != this) _open.value = null;
      },
      onHorizontalDragUpdate: (details) => controller.value =
          (controller.value - details.primaryDelta! / extent).clamp(0, 1),
      onHorizontalDragEnd: (details) => _settle(details.primaryVelocity ?? 0),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final action in widget.actions)
                    SizedBox(
                      width: widget.actionWidth,
                      child: Material(
                        color: action.color,
                        child: InkWell(
                          key: action.key,
                          onTap: () async {
                            if (busy) return;
                            busy = true;
                            close();
                            try {
                              await action.onTap();
                            } finally {
                              busy = false;
                            }
                          },
                          child: Center(
                            child: Text(
                              action.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) => Transform.translate(
                offset: Offset(-extent * controller.value, 0),
                child: child,
              ),
              child: Stack(
                children: [
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: widget.child,
                  ),
                  // While open, a tap on the row closes it instead of
                  // opening the row.
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => IgnorePointer(
                        ignoring: controller.value == 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: close,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
