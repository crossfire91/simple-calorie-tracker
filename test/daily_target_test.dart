import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';

void main() {
  DailyTargetProfile profile({
    required double weightKg,
    required double heightCm,
    required double paceKgPerWeek,
    BiologicalSex sex = BiologicalSex.male,
    int age = 35,
    ActivityLevel activity = ActivityLevel.light,
  }) {
    return DailyTargetProfile(
      mode: TargetMode.calculated,
      goal: GoalType.lose,
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activity: activity,
      paceKgPerWeek: paceKgPerWeek,
    );
  }

  test('95 kg male: 1% is 0.95 kg, 25% TDEE is the binding cap', () {
    final result = DailyTargetMath.tryCalculate(
      profile(weightKg: 95, heightCm: 175, paceKgPerWeek: 1.0),
    )!;

    expect(DailyTargetMath.maxHealthyLossKg(95, DailyTargetMath.bmi(95, 175)),
        closeTo(0.95, 0.001));
    expect(result.noteKind, TargetNote.loseCappedDeficit);
    expect(result.plannedKgPerWeek, closeTo(0.59, 0.05));
    expect(result.plannedKgPerWeek, lessThan(0.7));
    expect(result.wasCapped, isTrue);

    const de = S(AppLang.de);
    final note = de.targetNote(
      result.noteKind!,
      result.plannedKgPerWeek,
      weightKg: 95,
    );
    expect(note, contains('nicht die 1-%-Regel'));
    expect(note, contains('0,95'));
    expect(note, contains('25 %'));
  });

  test('lighter body: 1% binds before 1 kg', () {
    final result = DailyTargetMath.tryCalculate(
      profile(
        weightKg: 60,
        heightCm: 175,
        paceKgPerWeek: 1.0,
        activity: ActivityLevel.extra,
      ),
    )!;

    expect(result.noteKind, TargetNote.loseCappedPace);
    expect(result.plannedKgPerWeek, closeTo(0.60, 0.03));

    const de = S(AppLang.de);
    final note = de.targetNote(
      result.noteKind!,
      result.plannedKgPerWeek,
      weightKg: 60,
    );
    expect(note, contains('1 % von 60,00 kg = 0,60 kg'));
    expect(note, contains('gilt für alle als Deckel'));
  });
}
