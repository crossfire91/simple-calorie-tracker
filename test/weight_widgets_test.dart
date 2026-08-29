import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/widgets/loss_support_strip.dart';
import 'package:simple_calorie_tracker/widgets/weight_insight.dart';
import 'package:simple_calorie_tracker/widgets/weight_journey_card.dart';

Widget _wrap(Widget child, {AppLang lang = AppLang.en}) {
  return LocaleScope(
    controller: LocaleController(lang),
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final result = DailyTargetMath.tryCalculate(
    DailyTargetProfile(
      mode: TargetMode.calculated,
      goal: GoalType.lose,
      sex: BiologicalSex.female,
      age: 30,
      heightCm: 168,
      weightKg: 78.2,
      activity: ActivityLevel.light,
      paceKgPerWeek: 0.5,
    ),
  )!;

  testWidgets('manual lose goal stays lose when there is no weekly pace', (tester) async {
    final manual = DailyTargetMath.tryCalculate(
      DailyTargetProfile(
        mode: TargetMode.manual,
        goal: GoalType.lose,
        manualKcal: 1800,
      ),
    )!;

    await tester.pumpWidget(
      _wrap(
        WeightInsightBanner(
          result: manual,
          goal: GoalType.lose,
          currentKg: 95,
        ),
        lang: AppLang.de,
      ),
    );

    expect(find.textContaining('Abnehmen'), findsOneWidget);
    expect(find.textContaining('Halten'), findsNothing);
    expect(find.textContaining('Dieses Gewicht halten'), findsNothing);
  });

  testWidgets('insight banner names the weekly change with current weight', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WeightInsightBanner(
          result: result,
          goal: GoalType.lose,
          currentKg: 78.2,
        ),
      ),
    );

    expect(find.textContaining('Losing'), findsOneWidget);
    expect(find.textContaining('78.2 kg'), findsOneWidget);
    expect(find.textContaining('${result.targetKcal} kcal'), findsOneWidget);
  });

  testWidgets('manual journey card is visible without a calculated plan', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WeightJourneyCard(
          snapshot: WeightSnapshot(
            profile: DailyTargetProfile(
              mode: TargetMode.manual,
              manualKcal: 2100,
            ),
            result: DailyTargetMath.tryCalculate(
              DailyTargetProfile(mode: TargetMode.manual, manualKcal: 2100),
            ),
            logs: const [],
            trackedDateKeys: const {},
          ),
          onLogWeight: () {},
        ),
      ),
    );

    expect(find.text('YOUR JOURNEY'), findsOneWidget);
    expect(find.text('The series starts with today’s log.'), findsOneWidget);
    expect(find.text('Log a weigh-in to start the series.'), findsOneWidget);
  });

  testWidgets('journey card draws start, now and logged days', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WeightJourneyCard(
          snapshot: WeightSnapshot(
            profile: DailyTargetProfile(
              mode: TargetMode.calculated,
              goal: GoalType.lose,
              weightKg: 78.2,
            ),
            result: result,
            logs: const [
              WeightEntry(id: 'a', dateKey: '1.8.2026', weightKg: 80),
              WeightEntry(id: 'b', dateKey: '29.8.2026', weightKg: 78.2),
            ],
            trackedDateKeys: const {'29.8.2026'},
          ),
          onLogWeight: () {},
        ),
      ),
    );

    expect(find.text('YOUR JOURNEY'), findsOneWidget);
    expect(find.text('80.0 kg'), findsOneWidget);
    expect(find.text('78.2 kg'), findsOneWidget);
    expect(find.textContaining('−1.8 kg'), findsOneWidget);
    expect(find.text('DAYS YOU LOGGED'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNWidgets(2));
    expect(find.textContaining('−1.8 kg'), findsOneWidget);
    expect(find.text('DAYS YOU LOGGED'), findsOneWidget);
  });

  testWidgets('loss helpers are tappable product cards', (tester) async {
    await tester.pumpWidget(_wrap(const LossSupportStrip()));

    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('Kitchen scale'), findsOneWidget);
    await tester.tap(find.text('Kitchen scale'));
    await tester.pumpAndSettle();
    expect(find.textContaining('guesswork'), findsOneWidget);
  });

  testWidgets('German journey hint scales a 130 to 40 kg drop', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WeightJourneyCard(
          snapshot: WeightSnapshot(
            profile: DailyTargetProfile(
              mode: TargetMode.manual,
              manualKcal: 2100,
              goal: GoalType.lose,
            ),
            result: DailyTargetMath.tryCalculate(
              DailyTargetProfile(mode: TargetMode.manual, manualKcal: 2100),
            ),
            logs: const [
              WeightEntry(id: 'a', dateKey: '1.1.2026', weightKg: 130),
              WeightEntry(id: 'b', dateKey: '29.8.2026', weightKg: 40),
            ],
            trackedDateKeys: const {'29.8.2026'},
          ),
          onLogWeight: () {},
        ),
        lang: AppLang.de,
      ),
    );

    expect(find.textContaining('Etwas unter dem Startgewicht'), findsNothing);
    expect(find.textContaining('Das Ziel ist Halten'), findsNothing);
    expect(find.textContaining('Deutlich vor dem Plan'), findsOneWidget);
    expect(find.textContaining('−90.0 kg'), findsOneWidget);
  });

  testWidgets('German locale shows German journey copy', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WeightInsightBanner(
          result: result,
          goal: GoalType.lose,
          currentKg: 78.2,
        ),
        lang: AppLang.de,
      ),
    );

    expect(find.textContaining('Abnehmen'), findsOneWidget);
    expect(find.textContaining('Woche'), findsOneWidget);
    expect(find.textContaining('Bei 78.2 kg'), findsOneWidget);
  });
}
