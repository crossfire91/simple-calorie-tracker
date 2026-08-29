import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class RingHit {
  static const center = -1;
  static const leftover = -2;
}

class RingMeal {
  final String name;
  final double kcal;
  final DateTime? loggedAt;
  final String? photoPath;
  final Uint8List? photoBytes;

  const RingMeal({
    required this.name,
    required this.kcal,
    this.loggedAt,
    this.photoPath,
    this.photoBytes,
  });

  bool get hasPhoto =>
      (photoBytes != null && photoBytes!.isNotEmpty) || (photoPath?.isNotEmpty ?? false);
}

class MealRingSlice {
  final double start;
  final double sweep;
  final int mealIndex;

  const MealRingSlice({
    required this.start,
    required this.sweep,
    required this.mealIndex,
  });

  Color get color => AppColors.mealSwatch(mealIndex);

  bool sameAs(MealRingSlice other) {
    return start == other.start && sweep == other.sweep && mealIndex == other.mealIndex;
  }
}

class GoalHitSpan {
  final double start;
  final double width;
  final bool overflows;

  const GoalHitSpan({
    required this.start,
    required this.width,
    this.overflows = false,
  });
}

class GoalHitMath {
  static GoalHitSpan span({
    required double precedingKcal,
    required double kcal,
    required int budget,
  }) {
    if (budget <= 0 || kcal <= 0) {
      return const GoalHitSpan(start: 0, width: 0);
    }
    final start = (precedingKcal / budget).clamp(0.0, 1.0);
    final rawEnd = (precedingKcal + kcal) / budget;
    final overflows = rawEnd > 1;
    final end = rawEnd.clamp(0.0, 1.0);
    var width = end - start;
    if (width < 0) width = 0;
    if (overflows && width <= 0) {
      return const GoalHitSpan(start: 0.985, width: 0.015, overflows: true);
    }
    return GoalHitSpan(start: start, width: width, overflows: overflows);
  }
}

class MealRingMath {
  static List<MealRingSlice> slices({
    required List<double> mealKcals,
    required int budget,
    required double consumed,
  }) {
    if (budget <= 0 || consumed <= 0) return const [];
    final denom = consumed > budget ? consumed : budget.toDouble();
    var cursor = 0.0;
    final out = <MealRingSlice>[];
    for (var i = 0; i < mealKcals.length; i++) {
      final kcal = mealKcals[i];
      if (kcal <= 0) continue;
      final sweep = kcal / denom;
      if (sweep <= 0) continue;
      out.add(MealRingSlice(start: cursor, sweep: sweep, mealIndex: i));
      cursor += sweep;
    }
    return out;
  }

  static double turnOf(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = local - center;
    var turn = (math.atan2(delta.dy, delta.dx) + math.pi / 2) / (math.pi * 2);
    if (turn < 0) turn += 1;
    return turn;
  }

  static int? atTurn({
    required double turn,
    required List<MealRingSlice> slices,
    required double leftoverStart,
  }) {
    var t = turn % 1;
    if (t < 0) t += 1;
    if (leftoverStart < 1 && t >= leftoverStart) return RingHit.leftover;
    for (final slice in slices) {
      final end = slice.start + slice.sweep;
      if (t >= slice.start && t < end) return slice.mealIndex;
    }
    return leftoverStart < 1 ? RingHit.leftover : null;
  }

  /// `null` = outside the ring. [RingHit.center] or [RingHit.leftover] or a meal index.
  static int? hit({
    required Offset local,
    required Size size,
    required List<MealRingSlice> slices,
    required double reveal,
    double inset = 18,
    double stroke = 14,
  }) {
    if (size.shortestSide <= 0) return null;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - inset;
    final dist = (local - center).distance;
    if (dist > radius + stroke * 1.8) return null;
    if (dist < radius - stroke * 1.65) return RingHit.center;

    final leftoverStart = reveal < 1 ? reveal : 1.0;
    return atTurn(turn: turnOf(local, size), slices: slices, leftoverStart: leftoverStart) ??
        RingHit.center;
  }
}
