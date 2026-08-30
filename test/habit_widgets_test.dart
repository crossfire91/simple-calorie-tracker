import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/habit/ring_slices.dart';
import 'package:simple_calorie_tracker/widgets/calorie_ring.dart';
import 'package:simple_calorie_tracker/widgets/favorite_meals_strip.dart';
import 'package:simple_calorie_tracker/widgets/micro_goals_row.dart';
import 'package:simple_calorie_tracker/widgets/relative_day_chip.dart';
import 'package:simple_calorie_tracker/widgets/rest_of_day_coach.dart';
import 'package:simple_calorie_tracker/widgets/tracked_days_strip.dart';

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
  testWidgets('coach names a leftover meal in German', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RestOfDayCoach(
          consumed: 1600,
          budget: 2200,
          now: DateTime(2026, 8, 29, 14),
          favorites: const [
            FavoriteMeal(
              id: '1',
              name: 'Joghurt',
              kcalPer100g: 80,
              weightInGrams: 150,
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('600'), findsOneWidget);
    expect(find.textContaining('Joghurt'), findsWidgets);
  });

  testWidgets('coach chip logs the named favorite', (tester) async {
    FavoriteMeal? logged;
    await tester.pumpWidget(
      _wrap(
        RestOfDayCoach(
          consumed: 1600,
          budget: 2200,
          now: DateTime(2026, 8, 29, 14),
          favorites: const [
            FavoriteMeal(
              id: '1',
              name: 'Joghurt',
              kcalPer100g: 80,
              weightInGrams: 150,
            ),
          ],
          onLogFavorite: (fav) => logged = fav,
        ),
      ),
    );

    await tester.tap(find.textContaining('Joghurt'));
    expect(logged?.id, '1');
  });

  testWidgets('micro rings show breakfast and protein', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MicroGoalsRow(
          snapshot: MicroGoalMath.fromMeals(
            [
              LoggedBite(
                name: 'Eier',
                kcal: 320,
                proteinG: 24,
                loggedAt: DateTime(2026, 8, 29, 8),
              ),
            ],
            weightKg: 70,
            now: DateTime(2026, 8, 29, 18),
          ),
        ),
      ),
    );

    expect(find.text('TAGESZIELE'), findsOneWidget);
    expect(find.text('Frühstück'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.textContaining('24 / 112'), findsOneWidget);
  });

  testWidgets('heatmap shows a live streak chip', (tester) async {
    final today = DateTime.now();
    final key = '${today.day}.${today.month}.${today.year}';
    await tester.pumpWidget(
      _wrap(
        TrackedDaysStrip(
          trackedDateKeys: {key},
          digests: {
            key: DayDigest(dateKey: key, kcal: 2000, mealCount: 2),
          },
          kcalBudget: 2200,
        ),
      ),
    );

    expect(find.text('TAGE MIT EINTRAG'), findsOneWidget);
    expect(find.textContaining('in Folge'), findsOneWidget);
  });

  testWidgets('favorite tile logs on one tap', (tester) async {
    var logged = false;
    await tester.pumpWidget(
      _wrap(
        FavoriteMealsStrip(
          favorites: const [
            FavoriteMeal(
              id: '1',
              name: 'Oats',
              kcalPer100g: 380,
              weightInGrams: 80,
            ),
          ],
          onLog: (_) => logged = true,
          onRemove: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Oats'));
    expect(logged, isTrue);
    expect(find.text('FAVORITEN'), findsOneWidget);
  });

  testWidgets('ring fills leftover from empty on first appearance', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CalorieRing(
          consumed: 800,
          budget: 2200,
        ),
      ),
    );
    expect(find.text('800 / 2200'), findsNothing);
    expect(find.text('1400'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('1400'), findsOneWidget);
    expect(find.text('800 / 2200'), findsOneWidget);
  });

  testWidgets('ring shows leftover kcal and yesterday ghost', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CalorieRing(
          consumed: 800,
          budget: 2200,
          ghostConsumed: 1900,
          mealKcals: [300, 500],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1400'), findsOneWidget);
    expect(find.textContaining('GESTERN'), findsOneWidget);
    expect(find.text('800 / 2200'), findsOneWidget);
  });

  testWidgets('tapping a ring slice names the meal in the center', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CalorieRing(
          consumed: 1000,
          budget: 2000,
          meals: [
            RingMeal(name: 'Joghurt', kcal: 500, loggedAt: DateTime(2026, 8, 29, 8, 10)),
            RingMeal(name: 'Burger', kcal: 500, loggedAt: DateTime(2026, 8, 29, 13)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1000'), findsOneWidget);
    expect(find.text('Joghurt'), findsNothing);

    final center = tester.getCenter(find.byType(CalorieRing));
    await tester.tapAt(center + const Offset(70, -36));
    await tester.pumpAndSettle();

    expect(find.text('Joghurt'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.textContaining('08:10'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.text('Joghurt'), findsNothing);
    expect(find.text('1000'), findsOneWidget);
  });

  testWidgets('tapping the leftover names how much is still open', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CalorieRing(
          consumed: 1000,
          budget: 2000,
          meals: const [
            RingMeal(name: 'Joghurt', kcal: 500),
            RingMeal(name: 'Burger', kcal: 500),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(CalorieRing));
    await tester.tapAt(center + const Offset(-70, 0));
    await tester.pumpAndSettle();

    expect(find.text('NOCH OFFEN'), findsOneWidget);
    expect(find.text('Joghurt'), findsNothing);
  });

  testWidgets('relative day chip names today and days ago in German', (tester) async {
    await tester.pumpWidget(
      _wrap(RelativeDayChip(date: DateTime.now())),
    );
    expect(find.text('Heute'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(RelativeDayChip(date: DateTime.now().subtract(const Duration(days: 2)))),
    );
    expect(find.text('Vorgestern'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(RelativeDayChip(date: DateTime.now().subtract(const Duration(days: 5)))),
    );
    expect(find.text('Vor 5 Tagen'), findsOneWidget);
  });
}
