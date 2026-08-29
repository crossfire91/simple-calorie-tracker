import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/widgets/calorie_calendar.dart';

Widget _wrap(Widget child, {AppLang lang = AppLang.de}) {
  return LocaleScope(
    controller: LocaleController(lang),
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  final today = JourneyMath.dayOnly(DateTime.now());
  final monday = JourneyMath.mondayOf(today);
  final otherWeekday = monday == today ? monday.add(const Duration(days: 1)) : monday;

  testWidgets('shows the selected day digest and week caption', (tester) async {
    final key = JourneyMath.dateKey(today);
    await tester.pumpWidget(
      _wrap(
        CalorieCalendar(
          selectedDate: today,
          kcalBudget: 2200,
          digests: {
            key: DayDigest(dateKey: key, kcal: 1840, mealCount: 2, hasWeight: true),
          },
          onDateSelected: (_) {},
        ),
      ),
    );

    expect(find.textContaining('Diese Woche'), findsOneWidget);
    expect(find.textContaining('1840 / 2200 kcal'), findsOneWidget);
    expect(find.textContaining('2 Mahlzeiten'), findsOneWidget);
    expect(find.textContaining('gewogen'), findsOneWidget);
    expect(find.text('Heute'), findsNothing);
  });

  testWidgets('tapping another day reports the date', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(
      _wrap(
        CalorieCalendar(
          selectedDate: today,
          kcalBudget: 2200,
          digests: const {},
          onDateSelected: (date) => selected = date,
        ),
      ),
    );

    await tester.tap(find.text('${otherWeekday.day}').first);
    await tester.pumpAndSettle();

    expect(selected, otherWeekday);
  });

  testWidgets('today chip returns to today from another day', (tester) async {
    DateTime selected = otherWeekday;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return CalorieCalendar(
              selectedDate: selected,
              kcalBudget: 2200,
              digests: const {},
              onDateSelected: (date) => setState(() => selected = date),
            );
          },
        ),
      ),
    );

    expect(find.text('Heute'), findsOneWidget);
    await tester.tap(find.text('Heute'));
    await tester.pumpAndSettle();
    expect(selected, today);
  });

  testWidgets('month grid can pick a day in the open month', (tester) async {
    DateTime selected = today;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return CalorieCalendar(
              selectedDate: selected,
              kcalBudget: 2200,
              digests: const {},
              onDateSelected: (date) => setState(() => selected = date),
            );
          },
        ),
      ),
    );

    await tester.tap(find.textContaining(selected.year.toString()).first);
    await tester.pumpAndSettle();

    final pick = DateTime(selected.year, selected.month, 3);
    if (JourneyMath.sameDay(pick, selected)) {
      return;
    }
    await tester.tap(find.text('3').first);
    await tester.pumpAndSettle();
    expect(selected, pick);
  });
}
