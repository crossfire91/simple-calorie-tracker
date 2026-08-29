import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';

DailyTargetProfile _calculated({
  double weight = 80,
  GoalType goal = GoalType.lose,
}) {
  return DailyTargetProfile(
    mode: TargetMode.calculated,
    goal: goal,
    sex: BiologicalSex.female,
    age: 30,
    heightCm: 168,
    weightKg: weight,
    activity: ActivityLevel.light,
    paceKgPerWeek: 0.5,
  );
}

void main() {
  test('manual target never shows a weight projection', () {
    final profile = DailyTargetProfile(
      mode: TargetMode.manual,
      manualKcal: 2100,
      weightKg: 80,
    );

    expect(JourneyMath.projection(profile), isNull);
    expect(
      WeightSnapshot(
        profile: profile,
        result: JourneyMath.projection(profile),
        logs: const [],
        trackedDateKeys: const {},
      ).visible,
      isFalse,
    );
  });

  test('calculated lose target shows weekly loss from current weight', () {
    final at80 = JourneyMath.projection(_calculated());
    final at75 = JourneyMath.projection(_calculated(), currentWeight: 75);

    expect(at80, isNotNull);
    expect(at80!.plannedKgPerWeek, greaterThan(0.2));
    expect(at75, isNotNull);
    expect(at75!.targetKcal, isNot(at80.targetKcal));
  });

  test('maintain stays a hold even if weight is logged', () {
    final result = JourneyMath.projection(
      _calculated(goal: GoalType.maintain),
      currentWeight: 77.4,
    );

    expect(result, isNotNull);
    expect(result!.plannedKgPerWeek, 0);
    expect(
      JourneyMath.paceHint(
        goal: GoalType.maintain,
        startKg: 77.4,
        currentKg: 77.4,
        startDate: DateTime(2026, 8, 1),
        onDate: DateTime(2026, 8, 15),
        plannedKgPerWeek: 0,
      ),
      PaceHint.holdSteady,
    );
  });

  test('expected weight follows the planned weekly pace', () {
    final start = DateTime(2026, 8, 1);
    final twoWeeks = DateTime(2026, 8, 15);

    expect(
      JourneyMath.expectedWeight(
        startKg: 80,
        startDate: start,
        onDate: twoWeeks,
        goal: GoalType.lose,
        plannedKgPerWeek: 0.5,
      ),
      closeTo(79.0, 0.01),
    );
    expect(
      JourneyMath.expectedWeight(
        startKg: 70,
        startDate: start,
        onDate: twoWeeks,
        goal: GoalType.gain,
        plannedKgPerWeek: 0.25,
      ),
      closeTo(70.5, 0.01),
    );
  });

  test('snapshot uses the latest log as current weight', () {
    final snapshot = WeightSnapshot(
      profile: _calculated(weight: 80),
      result: JourneyMath.projection(_calculated(weight: 78)),
      logs: const [
        WeightEntry(id: 'a', dateKey: '1.8.2026', weightKg: 80),
        WeightEntry(id: 'b', dateKey: '15.8.2026', weightKg: 78.2),
      ],
      trackedDateKeys: const {'1.8.2026', '15.8.2026'},
    );

    expect(snapshot.visible, isTrue);
    expect(snapshot.showLossSupport, isTrue);
    expect(snapshot.startKg, 80);
    expect(snapshot.currentKg, 78.2);
    expect(snapshot.deltaKg, closeTo(-1.8, 0.01));
  });

  test('date keys round-trip', () {
    final date = DateTime(2026, 8, 29);
    expect(JourneyMath.dateKey(date), '29.8.2026');
    expect(JourneyMath.parseDateKey('29.8.2026'), DateTime(2026, 8, 29));
  });
}
