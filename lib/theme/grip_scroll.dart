import 'package:flutter/material.dart';

/// 1:1 with the finger while dragging; normal coast after a flick.
///
/// Skips bounce/stretch friction so a drag is not shortened vs the thumb.
class GripScrollPhysics extends ClampingScrollPhysics {
  const GripScrollPhysics({super.parent});

  @override
  GripScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return GripScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) => offset;
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
