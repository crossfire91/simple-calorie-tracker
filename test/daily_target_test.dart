import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/widgets/daily_target_form.dart';

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

  test('95 kg sedentary male: rest floor is 1874 kcal and ~0.34 kg', () {
    final result = DailyTargetMath.tryCalculate(
      profile(
        weightKg: 95,
        heightCm: 175,
        paceKgPerWeek: 1.0,
        activity: ActivityLevel.sedentary,
      ),
    )!;

    expect(result.noteKind, TargetNote.loseCappedFloor);
    expect(result.targetKcal, 1874);
    expect(result.plannedKgPerWeek, closeTo(0.34, 0.02));
    expect(result.wasCapped, isTrue);

    const de = S(AppLang.de);
    final note = de.targetNote(
      result.noteKind!,
      result.plannedKgPerWeek,
      weightKg: 95,
      tdee: result.tdee,
      targetKcal: result.targetKcal,
    );
    expect(note, contains('2249 kcal'));
    expect(note, contains('1874'));
    expect(note, contains('in Ruhe'));
    expect(note, contains('Muskel statt Fett'));
    expect(note, contains('nicht automatisch schneller'));
    expect(note, contains('mehr gehen'));
    expect(note, contains('schneller ab'));
    expect(note, isNot(contains('BMR')));
    expect(note, isNot(contains('Mifflin')));
    expect(note, isNot(contains('Abstand')));
  });

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
      tdee: result.tdee,
      bmr: result.bmr,
      targetKcal: result.targetKcal,
    );
    expect(note, contains('nicht das Essensziel'));
    expect(note, contains('ganzes Kilo'));
    expect(note, contains('Muskel statt als Fett'));
    expect(note, contains('schneller abnehmen'));
    expect(note, contains('demselben Essen'));
    expect(note, isNot(contains('ACSM')));
    expect(note, isNot(contains('Abstand')));
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
      tdee: result.tdee,
      bmr: result.bmr,
      targetKcal: result.targetKcal,
    );
    expect(note, contains('Bei 60,00 kg'));
    expect(note, contains('0,60 kg'));
    expect(note, contains('1 % des Körpergewichts'));
    expect(note, contains('100 kg'));
    expect(note, contains('Muskel, nicht nur Fett'));
    expect(note, contains('schneller abnehmen'));
    expect(note, contains('Bewegung im Alltag'));
    expect(note, isNot(contains('ACSM')));
    expect(note, isNot(contains('Deckel')));
  });

  test('older small sedentary woman: burn already at the floor', () {
    final result = DailyTargetMath.tryCalculate(
      profile(
        weightKg: 50,
        heightCm: 160,
        paceKgPerWeek: 0.5,
        sex: BiologicalSex.female,
        age: 70,
        activity: ActivityLevel.sedentary,
      ),
    )!;

    expect(result.noteKind, TargetNote.loseNoRoom);
    expect(result.plannedKgPerWeek, 0);
    expect(result.targetKcal, result.tdee.round());
    expect(result.targetKcal, lessThan(1200));

    const de = S(AppLang.de);
    final note = de.targetNote(
      result.noteKind!,
      result.plannedKgPerWeek,
      tdee: result.tdee,
      targetKcal: result.targetKcal,
    );
    expect(note, contains('Mangel, kein Fortschritt'));
    expect(note, contains('bleibt das Ziel beim Halten'));
    expect(note, contains('Platz zum Abnehmen'));
    expect(note, isNot(contains('BMR')));
    expect(note, isNot(contains('Abstand')));
  });

  test('AND floor, not rest burn: 55 kg sedentary woman', () {
    final result = DailyTargetMath.tryCalculate(
      profile(
        weightKg: 55,
        heightCm: 160,
        paceKgPerWeek: 0.5,
        sex: BiologicalSex.female,
        age: 50,
        activity: ActivityLevel.sedentary,
      ),
    )!;

    expect(result.noteKind, TargetNote.loseCappedFloor);
    expect(result.targetKcal, 1200);
    expect(result.bmr, lessThan(1200));
    expect(result.plannedKgPerWeek, greaterThan(0.05));

    const de = S(AppLang.de);
    final note = de.targetNote(
      result.noteKind!,
      result.plannedKgPerWeek,
      tdee: result.tdee,
      bmr: result.bmr,
      targetKcal: result.targetKcal,
    );
    expect(note, contains('1200 kcal'));
    expect(note, contains('ärztliche Begleitung'));
    expect(note, contains('Muskel ab'));
    expect(note, contains('schneller abnehmen'));
    expect(note, contains('ohne noch weniger zu essen'));
    expect(note, isNot(contains('Praxis')));
    expect(note, isNot(contains('BMR')));
  });

  test('underweight blocks a deficit and explains hold', () {
    final result = DailyTargetMath.tryCalculate(
      profile(weightKg: 50, heightCm: 175, paceKgPerWeek: 0.5),
    )!;

    expect(result.noteKind, TargetNote.underweightBlocked);
    expect(result.plannedKgPerWeek, 0);
    expect(result.underweightBlocked, isTrue);

    const de = S(AppLang.de);
    expect(
      de.targetNote(result.noteKind!, 0, weightKg: 50),
      contains('bereits niedrig'),
    );
  });

  test('gain cap explains the slow surplus', () {
    final result = DailyTargetMath.tryCalculate(
      DailyTargetProfile(
        mode: TargetMode.calculated,
        goal: GoalType.gain,
        sex: BiologicalSex.male,
        age: 35,
        heightCm: 175,
        weightKg: 60,
        activity: ActivityLevel.light,
        paceKgPerWeek: 0.5,
      ),
    )!;

    expect(result.noteKind, TargetNote.gainCapped);
    expect(result.plannedKgPerWeek, closeTo(0.30, 0.03));

    const de = S(AppLang.de);
    final note = de.targetNote(result.noteKind!, result.plannedKgPerWeek);
    expect(note, contains('+0,30 kg'));
    expect(note, contains('vor allem Fett'));
    expect(note, isNot(contains('ISSN')));
    expect(note, isNot(contains('TDEE')));
    expect(note, isNot(contains('0,5 %')));
  });

  testWidgets('manual target form uses German labels', (tester) async {
    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.de),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTargetForm(
                initial: DailyTargetProfile(mode: TargetMode.manual, manualKcal: 2200),
                onSave: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Or type it'), findsNothing);
    expect(find.text('e.g. 2200'), findsNothing);
    expect(find.text('Oder tippen'), findsOneWidget);
    expect(find.text('z. B. 2200'), findsOneWidget);
    expect(find.text('Startgewicht'), findsNothing);
    expect(find.text('Wie schnell'), findsNothing);
    expect(find.text('ZIEL'), findsOneWidget);
    expect(find.text('Abnehmen'), findsOneWidget);
    expect(find.text('Halten'), findsOneWidget);
    expect(find.text('Zunehmen'), findsOneWidget);
    expect(find.text('Startgewicht angeben (optional)'), findsOneWidget);
    expect(find.text('kg/wk'), findsNothing);
  });

  testWidgets('manual form saves the calorie number without a required weight',
      (tester) async {
    DailyTargetProfile? saved;

    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.en),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTargetForm(
                initial: DailyTargetProfile(
                  mode: TargetMode.manual,
                  manualKcal: 2200,
                ),
                onSave: (_, profile) => saved = profile,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pace'), findsNothing);
    expect(find.text('Starting weight'), findsNothing);
    await tester.tap(find.text('Keep'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save this target'));
    await tester.tap(find.text('Save this target'));
    await tester.pump();
    expect(saved?.mode, TargetMode.manual);
    expect(saved?.manualKcal, 2200);
    expect(saved?.goal, GoalType.maintain);
    expect(saved?.weightKg, isNull);
  });

  testWidgets('manual form can add an optional starting weight', (tester) async {
    DailyTargetProfile? saved;

    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.en),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTargetForm(
                initial: DailyTargetProfile(
                  mode: TargetMode.manual,
                  manualKcal: 2200,
                ),
                onSave: (_, profile) => saved = profile,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add starting weight (optional)'));
    await tester.pump();
    expect(find.text('Starting weight'), findsOneWidget);
    expect(find.text('Skip weight'), findsOneWidget);

    await tester.ensureVisible(find.text('Save this target'));
    await tester.tap(find.text('Save this target'));
    await tester.pump();
    expect(saved?.weightKg, 72);
  });

  bool _anyStepLocked(WidgetTester tester) {
    return tester
        .widgetList<IgnorePointer>(find.byType(IgnorePointer))
        .any((widget) => widget.ignoring);
  }

  Future<void> pumpCalculatedForm(
    WidgetTester tester, {
    required DailyTargetProfile initial,
    bool firstRun = false,
  }) async {
    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.en),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyTargetForm(
                initial: initial,
                firstRun: firstRun,
                onSave: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('first run blurs later steps until goal and sex are picked',
      (tester) async {
    await pumpCalculatedForm(
      tester,
      firstRun: true,
      initial: DailyTargetProfile.fresh(),
    );

    expect(find.text('—'), findsOneWidget);
    expect(_anyStepLocked(tester), isTrue);
    expect(find.text('Start tracking'), findsOneWidget);
  });

  testWidgets('editing a saved calculation shows every step without blur',
      (tester) async {
    await pumpCalculatedForm(
      tester,
      initial: profile(weightKg: 95, heightCm: 175, paceKgPerWeek: 0.5),
    );

    expect(find.text('—'), findsNothing);
    expect(_anyStepLocked(tester), isFalse);
    expect(find.text('Save this target'), findsOneWidget);
    expect(find.text('SEX'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Typical week'), findsOneWidget);
  });

  testWidgets('switching to calculate on a saved manual target does not blur',
      (tester) async {
    await pumpCalculatedForm(
      tester,
      initial: DailyTargetProfile(
        mode: TargetMode.manual,
        manualKcal: 2200,
        weightKg: 80,
      ),
    );

    await tester.tap(find.text('Calculate'));
    await tester.pump();

    expect(_anyStepLocked(tester), isFalse);
    expect(find.text('SEX'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
  });
}
