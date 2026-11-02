import 'package:flutter/widgets.dart';

/// Snap only the header's partial range. Nested list momentum and saved tab
/// offsets remain under NestedScrollView's own coordinator.
class ProfileSnapScrollPhysics extends ClampingScrollPhysics {
  const ProfileSnapScrollPhysics({
    required this.headerExtent,
    required this.dragDirection,
    super.parent,
  });

  final double Function() headerExtent;
  final double Function() dragDirection;

  @override
  ProfileSnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ProfileSnapScrollPhysics(
        headerExtent: headerExtent,
        dragDirection: dragDirection,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final natural = super.createBallisticSimulation(position, velocity);
    final direction = dragDirection();
    final start = position.minScrollExtent;
    final end = headerExtent();
    final tolerance = toleranceFor(position);
    if (direction == 0 ||
        end <= start ||
        position.pixels <= start + tolerance.distance ||
        position.pixels >= end - tolerance.distance) {
      return natural;
    }
    // A fling already reaching an endpoint can continue naturally into the list.
    if (natural != null) {
      final resting = natural.x(10);
      if (resting <= start || resting >= end) return natural;
    }
    final target = direction > 0 ? end : start;
    return ScrollSpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 1.05),
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
