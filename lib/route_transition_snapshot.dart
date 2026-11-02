import 'package:flutter/material.dart';

/// Freeze complex page painting only for the duration of a route transition.
/// The live tree remains mounted and resumes painting as soon as motion ends.
class RouteTransitionSnapshot extends StatefulWidget {
  const RouteTransitionSnapshot({super.key, required this.child});
  final Widget child;
  @override
  State<RouteTransitionSnapshot> createState() =>
      _RouteTransitionSnapshotState();
}

class _RouteTransitionSnapshotState extends State<RouteTransitionSnapshot> {
  final controller = SnapshotController();
  Animation<double>? primary, secondary;

  void update(AnimationStatus _) {
    controller.allowSnapshotting =
        primary?.status.isAnimating == true ||
        secondary?.status.isAnimating == true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (primary != route?.animation || secondary != route?.secondaryAnimation) {
      primary?.removeStatusListener(update);
      secondary?.removeStatusListener(update);
      primary = route?.animation;
      secondary = route?.secondaryAnimation;
      primary?.addStatusListener(update);
      secondary?.addStatusListener(update);
    }
    update(AnimationStatus.dismissed);
  }

  @override
  void dispose() {
    primary?.removeStatusListener(update);
    secondary?.removeStatusListener(update);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SnapshotWidget(
    controller: controller,
    mode: SnapshotMode.permissive,
    autoresize: true,
    child: widget.child,
  );
}
