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
  test('manual target still shows the weight journey', () {
    final profile = DailyTargetProfile(
      mode: TargetMode.manual,
      manualKcal: 2100,
      weightKg: 80,
    );
    final result = JourneyMath.projection(profile);

    expect(result, isNotNull);
    expect(result!.targetKcal, 2100);
    expect(result.plannedKgPerWeek, 0);
    expect(
      WeightSnapshot(
        profile: profile,
        result: result,
        logs: const [],
        trackedDateKeys: const {},
      ).visible,
      isTrue,
    );
    expect(
      WeightSnapshot(
        profile: profile,
        result: result,
        logs: const [],
        trackedDateKeys: const {},
      ).showLossSupport,
      isFalse,
    );
    expect(
      WeightSnapshot(
        profile: profile,
        result: result,
        logs: const [],
        trackedDateKeys: const {},
      ).currentKg,
      isNull,
    );
  });

  test('manual snapshot uses logged weight, not a silent profile default', () {
    final snapshot = WeightSnapshot(
      profile: DailyTargetProfile(
        mode: TargetMode.manual,
        manualKcal: 2100,
        weightKg: 72,
      ),
      result: JourneyMath.projection(
        DailyTargetProfile(mode: TargetMode.manual, manualKcal: 2100),
      ),
      logs: const [
        WeightEntry(id: 'a', dateKey: '1.8.2026', weightKg: 81.4),
      ],
      trackedDateKeys: const {'1.8.2026'},
    );

    expect(snapshot.visible, isTrue);
    expect(snapshot.startKg, 81.4);
    expect(snapshot.currentKg, 81.4);
  });

  test('calculated lose target shows weekly loss from current weight', () {
    final at80 = JourneyMath.projection(_calculated());
    final at75 = JourneyMath.projection(_calculated(), currentWeight: 75);

    expect(at80, isNotNull);
    expect(at80!.plannedKgPerWeek, greaterThan(0.2));
    expect(at75, isNotNull);
    expect(at75!.targetKcal, isNot(at80.targetKcal));
  });

  test('a zero weekly plan is treated as a hold', () {
    expect(
      JourneyMath.paceHint(
        goal: GoalType.lose,
        startKg: 80,
        currentKg: 80.1,
        startDate: DateTime(2026, 8, 1),
        onDate: DateTime(2026, 8, 15),
        plannedKgPerWeek: 0,
      ),
      PaceHint.holdSteady,
    );
  });

  test('a large drop is not "a bit below start / maintain"', () {
    expect(
      JourneyMath.paceHint(
        goal: GoalType.lose,
        startKg: 130,
        currentKg: 40,
        startDate: DateTime(2026, 1, 1),
        onDate: DateTime(2026, 8, 29),
        plannedKgPerWeek: 0,
      ),
      PaceHint.aheadMuch,
    );
    expect(
      JourneyMath.paceHint(
        goal: GoalType.maintain,
        startKg: 130,
        currentKg: 40,
        startDate: DateTime(2026, 1, 1),
        onDate: DateTime(2026, 8, 29),
        plannedKgPerWeek: 0,
      ),
      PaceHint.holdDownMuch,
    );
    expect(
      JourneyMath.paceHint(
        goal: GoalType.maintain,
        startKg: 80,
        currentKg: 79.4,
        startDate: DateTime(2026, 8, 1),
        onDate: DateTime(2026, 8, 15),
        plannedKgPerWeek: 0,
      ),
      PaceHint.holdDown,
    );
  });

  test('manual snapshot judges the logged change, not a silent hold', () {
    final snapshot = WeightSnapshot(
      profile: DailyTargetProfile(
        mode: TargetMode.manual,
        manualKcal: 2100,
        goal: GoalType.lose,
      ),
      result: JourneyMath.projection(
        DailyTargetProfile(mode: TargetMode.manual, manualKcal: 2100),
      ),
      logs: const [
        WeightEntry(id: 'a', dateKey: '1.1.2026', weightKg: 130),
        WeightEntry(id: 'b', dateKey: '29.8.2026', weightKg: 40),
      ],
      trackedDateKeys: const {'1.1.2026', '29.8.2026'},
    );

    expect(snapshot.journeyGoal, GoalType.lose);
    expect(snapshot.journeyPaceKgPerWeek, 0);
    expect(snapshot.startKg, 130);
    expect(snapshot.currentKg, 40);
    expect(
      JourneyMath.paceHint(
        goal: snapshot.journeyGoal,
        startKg: snapshot.startKg!,
        currentKg: snapshot.currentKg!,
        startDate: snapshot.startedAt!,
        onDate: DateTime(2026, 8, 29),
        plannedKgPerWeek: snapshot.journeyPaceKgPerWeek,
      ),
      PaceHint.aheadMuch,
    );
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
