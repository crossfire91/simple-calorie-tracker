import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/habit/ring_slices.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

void main() {
  test('under budget slices sit on the daily target', () {
    final slices = MealRingMath.slices(
      mealKcals: [400, 200],
      budget: 2000,
      consumed: 600,
    );

    expect(slices, hasLength(2));
    expect(slices[0].start, 0);
    expect(slices[0].sweep, closeTo(0.2, 0.0001));
    expect(slices[1].start, closeTo(0.2, 0.0001));
    expect(slices[1].sweep, closeTo(0.1, 0.0001));
    expect(slices[0].color, AppColors.mealSwatch(0));
    expect(slices[1].color, AppColors.mealSwatch(1));
  });

  test('over budget slices fill the whole ring from what was eaten', () {
    final slices = MealRingMath.slices(
      mealKcals: [800, 800, 800],
      budget: 2000,
      consumed: 2400,
    );

    expect(slices, hasLength(3));
    expect(slices[0].sweep, closeTo(800 / 2400, 0.0001));
    expect(
      slices.fold<double>(0, (sum, slice) => sum + slice.sweep),
      closeTo(1, 0.0001),
    );
  });

  test('a later meal sits further along the daily calorie bar', () {
    final lunch = GoalHitMath.span(
      precedingKcal: 600,
      kcal: 400,
      budget: 2000,
    );

    expect(lunch.start, closeTo(0.3, 0.0001));
    expect(lunch.width, closeTo(0.2, 0.0001));
    expect(lunch.overflows, isFalse);
  });

  test('a meal past the daily target marks overflow at the end', () {
    final extra = GoalHitMath.span(
      precedingKcal: 2100,
      kcal: 300,
      budget: 2000,
    );

    expect(extra.overflows, isTrue);
    expect(extra.start, closeTo(0.985, 0.0001));
  });

  test('zero kcal meals stay out of the ring but keep later colors stable', () {
    final slices = MealRingMath.slices(
      mealKcals: [0, 500],
      budget: 2000,
      consumed: 500,
    );

    expect(slices, hasLength(1));
    expect(slices.single.mealIndex, 1);
    expect(slices.single.color, AppColors.mealSwatch(1));
  });

  test('a tap on the right of the ring hits the first half', () {
    final slices = MealRingMath.slices(
      mealKcals: [1000, 1000],
      budget: 2000,
      consumed: 2000,
    );
    const size = Size(200, 200);

    expect(
      MealRingMath.hit(local: const Offset(182, 100), size: size, slices: slices, reveal: 1),
      0,
    );
    expect(
      MealRingMath.hit(local: const Offset(18, 100), size: size, slices: slices, reveal: 1),
      1,
    );
    expect(
      MealRingMath.hit(local: const Offset(100, 100), size: size, slices: slices, reveal: 1),
      RingHit.center,
    );
  });

  test('the open leftover of the day is its own hit target', () {
    final slices = MealRingMath.slices(
      mealKcals: [500, 500],
      budget: 2000,
      consumed: 1000,
    );
    const size = Size(200, 200);

    expect(
      MealRingMath.hit(local: const Offset(18, 100), size: size, slices: slices, reveal: 0.5),
      RingHit.leftover,
    );
    expect(
      MealRingMath.atTurn(turn: 0.75, slices: slices, leftoverStart: 0.5),
      RingHit.leftover,
    );
    expect(
      MealRingMath.atTurn(turn: 0.1, slices: slices, leftoverStart: 0.5),
      0,
    );
  });
}
