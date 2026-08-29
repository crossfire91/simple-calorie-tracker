import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/text_meal_parser.dart';

void main() {
  test('weighted meal kcal come from grounded rows, not a model guess', () {
    const chicken = DetectedFood(name: 'Chicken', queryEn: 'chicken breast grilled', grams: 150);
    const rice = DetectedFood(name: 'Rice', queryEn: 'rice white cooked', grams: 200);
    const estimate = MealEstimate(
      mealName: 'Chicken and rice',
      items: [
        GroundedFood(
          detected: chicken,
          matchedName: 'Chicken, broilers, breast, grilled',
          kcalPer100g: 165,
          source: NutritionSource.usda,
        ),
        GroundedFood(
          detected: rice,
          matchedName: 'Rice, white, cooked',
          kcalPer100g: 130,
          source: NutritionSource.usda,
        ),
      ],
    );

    expect(estimate.totalGrams, 350);
    expect(estimate.totalKcal, 248 + 260);
    expect(estimate.kcalPer100g, 145);
    expect(estimate.sourcesLabel, 'USDA');
  });

  test('free text keeps user grams and drops the restaurant clause', () {
    final parsed = parseMealNote('greek pizza at nikos, 350g');
    expect(parsed.grams, 350);
    expect(parsed.name.toLowerCase(), contains('greek pizza'));

    final food = detectedFromNote('greek pizza at nikos, 350g');
    expect(food.grams, 350);
    expect(food.altQueries, isNotEmpty);
  });

  test('unmatched items still count toward logged grams', () {
    const pizza = DetectedFood(name: 'Greek pizza', queryEn: 'greek pizza', grams: 350);
    const estimate = MealEstimate(
      mealName: 'Greek pizza',
      unmatchedItems: [pizza],
    );
    expect(estimate.totalGrams, 350);
    expect(estimate.totalKcal, 0);
    expect(estimate.items, isEmpty);
  });

  test('web fallback is labeled unverified and does not look like USDA', () {
    const pizza = DetectedFood(name: 'Greek pizza', queryEn: 'greek pizza', grams: 350);
    const estimate = MealEstimate(
      mealName: 'Greek pizza',
      items: [
        GroundedFood(
          detected: pizza,
          matchedName: 'Restaurant nutrition PDF',
          kcalPer100g: 260,
          source: NutritionSource.web,
          sourceTitle: 'Nikos menu',
        ),
      ],
    );

    expect(estimate.hasWebSource, isTrue);
    expect(estimate.items.single.unverified, isTrue);
    expect(estimate.sourcesLabel, 'Web');
    expect(estimate.totalKcal, 910);
  });

  test('known menu grams win over the model portion guess', () {
    const chicken = DetectedFood(name: 'Chicken', queryEn: 'chicken', grams: 180);
    const rice = DetectedFood(name: 'Rice', queryEn: 'rice', grams: 220);
    const estimate = MealEstimate(
      mealName: 'Plate',
      items: [
        GroundedFood(
          detected: chicken,
          matchedName: 'Chicken',
          kcalPer100g: 165,
          source: NutritionSource.usda,
        ),
        GroundedFood(
          detected: rice,
          matchedName: 'Rice',
          kcalPer100g: 130,
          source: NutritionSource.usda,
        ),
      ],
    );

    final locked = estimate.withKnownGrams(300);
    expect(locked.totalGrams, 300);
    expect(locked.items[0].grams + locked.items[1].grams, 300);
    expect(locked.items[0].grams, lessThan(locked.items[1].grams));
  });
}
