import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/widgets/meal_card.dart';

Widget _wrap(Widget child, {AppLang lang = AppLang.de}) {
  return LocaleScope(
    controller: LocaleController(lang),
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

MealCard _card({
  required double kcal,
  int dailyBudget = 2000,
  double precedingKcal = 0,
  DateTime? loggedAt,
}) {
  return MealCard(
    name: 'Joghurt',
    kcal: kcal,
    grams: 200,
    kcalPer100g: kcal.round() ~/ 2,
    dailyBudget: dailyBudget,
    precedingKcal: precedingKcal,
    loggedAt: loggedAt,
    hasPhotos: false,
    onAddServing: () {},
    onDelete: () {},
  );
}

void main() {
  testWidgets('meal card paints how hard the entry hits the daily target', (tester) async {
    await tester.pumpWidget(_wrap(_card(kcal: 500)));
    await tester.pumpAndSettle();

    expect(find.text('500 kcal'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('a meal over the daily target stays visibly over 100%', (tester) async {
    await tester.pumpWidget(_wrap(_card(kcal: 2500)));
    await tester.pumpAndSettle();

    expect(find.text('125%'), findsOneWidget);
  });

  testWidgets('card shows when the meal was logged', (tester) async {
    await tester.pumpWidget(
      _wrap(_card(kcal: 400, precedingKcal: 600, loggedAt: DateTime(2026, 8, 29, 13, 5))),
    );
    await tester.pumpAndSettle();

    expect(find.text('20%'), findsOneWidget);
    expect(find.textContaining('13:05'), findsOneWidget);
  });

  testWidgets('no share bar without a daily target', (tester) async {
    await tester.pumpWidget(_wrap(_card(kcal: 500, dailyBudget: 0)));
    await tester.pumpAndSettle();

    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('tapping a card edits it', (tester) async {
    var edited = false;
    await tester.pumpWidget(
      _wrap(
        MealCard(
          name: 'Joghurt',
          kcal: 400,
          grams: 200,
          kcalPer100g: 200,
          dailyBudget: 2000,
          hasPhotos: false,
          onEdit: () => edited = true,
          onSelect: () {},
          onAddServing: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joghurt'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });

  testWidgets('meal sort toggle switches newest and oldest', (tester) async {
    var newest = true;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return MealSortToggle(
              newestFirst: newest,
              onChanged: (value) => setState(() => newest = value),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Neueste'), findsOneWidget);
    expect(find.text('Älteste'), findsOneWidget);

    await tester.tap(find.text('Älteste'));
    await tester.pumpAndSettle();
    expect(newest, isFalse);

    await tester.tap(find.text('Neueste'));
    await tester.pumpAndSettle();
    expect(newest, isTrue);
  });
}
