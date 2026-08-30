import 'package:flutter/material.dart';

/// Finger-true scrolling: the list moves by the drag delta, then stops.
class GripScrollPhysics extends ClampingScrollPhysics {
  const GripScrollPhysics({super.parent});

  @override
  GripScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return GripScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) => offset;

  @override
  double get minFlingVelocity => double.infinity;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    return null;
  }
}

class GripScrollBehavior extends MaterialScrollBehavior {
  const GripScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const GripScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
