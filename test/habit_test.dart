import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';
import 'package:simple_calorie_tracker/habit/rest_of_day.dart';
import 'package:simple_calorie_tracker/habit/streak.dart';

void main() {
  test('streak counts back from today or yesterday', () {
    expect(StreakMath.currentStreak(const {}, now: DateTime(2026, 8, 29)), 0);
    expect(
      StreakMath.currentStreak(
        {'27.8.2026', '28.8.2026', '29.8.2026'},
        now: DateTime(2026, 8, 29, 19),
      ),
      3,
    );
    expect(
      StreakMath.currentStreak(
        {'27.8.2026', '28.8.2026'},
        now: DateTime(2026, 8, 29, 9),
      ),
      2,
    );
    expect(
      StreakMath.currentStreak(
        {'26.8.2026'},
        now: DateTime(2026, 8, 29),
      ),
      0,
    );
  });

  test('heatmap tone follows the budget', () {
    const logged = DayDigest(dateKey: '29.8.2026', kcal: 2100, mealCount: 2);
    expect(StreakMath.tone(null, 2200), DayTone.empty);
    expect(StreakMath.tone(logged, 2200), DayTone.closed);
    expect(
      StreakMath.tone(
        const DayDigest(dateKey: 'x', kcal: 2000, mealCount: 1),
        2200,
      ),
      DayTone.under,
    );
    expect(
      StreakMath.tone(
        const DayDigest(dateKey: 'x', kcal: 900, mealCount: 1),
        2200,
      ),
      DayTone.under,
    );
    expect(
      StreakMath.tone(
        const DayDigest(dateKey: 'x', kcal: 2600, mealCount: 1),
        2200,
      ),
      DayTone.over,
    );
  });

  test('ring close fires once when the budget is crossed', () {
    expect(StreakMath.ringJustClosed(1800, 2200, 2200), isTrue);
    expect(StreakMath.ringJustClosed(2200, 2400, 2200), isFalse);
    expect(StreakMath.ringJustClosed(100, 400, 2200), isFalse);
  });

  test('protein estimate is higher for chicken than pizza', () {
    expect(
      ProteinMath.estimateGrams(name: 'Hähnchen', kcal: 400),
      greaterThan(ProteinMath.estimateGrams(name: 'Pizza', kcal: 400)),
    );
    expect(
      ProteinMath.estimateGrams(name: 'Reis', kcal: 400),
      lessThan(ProteinMath.estimateGrams(name: '2 Eier', kcal: 400)),
    );
    expect(ProteinMath.dailyTargetGrams(70), 112);
  });

  test('rest of day prefers a favorite that still fits', () {
    final plan = RestOfDayMath.plan(
      consumed: 1600,
      budget: 2200,
      favorites: const [
        FavoriteMeal(
          id: '1',
          name: 'Joghurt',
          kcalPer100g: 80,
          weightInGrams: 150,
        ),
      ],
      meals: const [
        LoggedBite(name: 'Mittag', kcal: 1600, proteinG: 90),
      ],
      now: DateTime(2026, 8, 29, 15),
    );
    expect(plan.remaining, 600);
    expect(plan.mood, CoachMood.nextPlate);
    expect(plan.suggestions, isNotEmpty);
    expect(plan.suggestions.first.fromFavorite, isTrue);
    expect(plan.suggestions.first.nameDe, 'Joghurt');
  });

  test('coach is morning-open before the first plate', () {
    final plan = RestOfDayMath.plan(
      consumed: 0,
      budget: 2200,
      favorites: const [
        FavoriteMeal(
          id: '1',
          name: 'Haferbrei',
          kcalPer100g: 380,
          weightInGrams: 80,
        ),
      ],
      now: DateTime(2026, 8, 29, 8),
    );
    expect(plan.mood, CoachMood.morningOpen);
    expect(plan.suggestions.first.fromFavorite, isTrue);
  });

  test('coach prefers protein when the gap is large', () {
    final plan = RestOfDayMath.plan(
      consumed: 1400,
      budget: 2200,
      favorites: const [
        FavoriteMeal(
          id: 'sweet',
          name: 'Schokolade',
          kcalPer100g: 550,
          weightInGrams: 20,
          proteinG: 1,
        ),
        FavoriteMeal(
          id: 'chicken',
          name: 'Hähnchen',
          kcalPer100g: 165,
          weightInGrams: 200,
          proteinG: 46,
        ),
      ],
      meals: const [
        LoggedBite(name: 'Toast', kcal: 1400, proteinG: 12),
      ],
      weightKg: 70,
      now: DateTime(2026, 8, 29, 15),
    );
    expect(plan.mood, CoachMood.proteinPush);
    expect(plan.suggestions.first.favoriteId, 'chicken');
  });

  test('late evening with little room becomes a sip', () {
    final plan = RestOfDayMath.plan(
      consumed: 2100,
      budget: 2200,
      now: DateTime(2026, 8, 29, 22),
    );
    expect(plan.mood, CoachMood.lateSip);
    expect(plan.suggestions, isEmpty);
  });

  test('micro goals: breakfast, protein and late snack', () {
    final morning = MicroGoalMath.fromMeals(
      [
        LoggedBite(
          name: 'eggs',
          kcal: 320,
          proteinG: 24,
          loggedAt: DateTime(2026, 8, 29, 8, 10),
        ),
      ],
      weightKg: 70,
      now: DateTime(2026, 8, 29, 18),
    );
    expect(morning.breakfast.done, isTrue);
    expect(morning.noLate.state, MicroGoalState.open);
    expect(morning.proteinGrams, 24);

    final late = MicroGoalMath.fromMeals(
      [
        LoggedBite(
          name: 'chips',
          kcal: 400,
          loggedAt: DateTime(2026, 8, 29, 22, 5),
        ),
      ],
      now: DateTime(2026, 8, 29, 22, 30),
    );
    expect(late.breakfast.state, MicroGoalState.missed);
    expect(late.noLate.state, MicroGoalState.missed);

    final emptyEvening = MicroGoalMath.fromMeals(
      const [],
      now: DateTime(2026, 8, 29, 19),
    );
    expect(emptyEvening.breakfast.state, MicroGoalState.open);
    expect(emptyEvening.noLate.state, MicroGoalState.open);
  });
}
