import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/nutrition/ingredient_memory.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';

void main() {
  test('last logged ingredient density wins', () {
    final shake = MealEstimate(
      mealName: 'Shake',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
          matchedName: 'Almond milk',
          kcalPer100g: 24,
          source: NutritionSource.manual,
        ),
      ],
    );
    final memory = IngredientMemory.fromMeals([
      LoggedPlate(name: 'Shake', kcalPer100g: 40, breakdown: shake.encode(), loggedAt: 20),
      LoggedPlate(name: 'Mandelmilch', kcalPer100g: 15, loggedAt: 10),
    ]);

    expect(memory.lookup('mandelmilch'), 24);
    expect(memory.lookup('  Mandelmilch '), 24);
  });

  test('a simple plate without a recipe still teaches its name', () {
    final memory = IngredientMemory.fromMeals([
      const LoggedPlate(name: 'Skyr', kcalPer100g: 62, loggedAt: 2),
      const LoggedPlate(name: 'Skyr', kcalPer100g: 55, loggedAt: 1),
    ]);

    expect(memory.lookup('Skyr'), 62);
  });

  test('a recipe name is not stored as its own density', () {
    final shake = MealEstimate(
      mealName: 'Shake mit Mandelmilch',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
          matchedName: 'Almond milk',
          kcalPer100g: 24,
          source: NutritionSource.manual,
        ),
      ],
    );
    final memory = IngredientMemory.fromMeals([
      LoggedPlate(
        name: 'Shake mit Mandelmilch',
        kcalPer100g: 40,
        breakdown: shake.encode(),
      ),
    ]);

    expect(memory.lookup('Shake mit Mandelmilch'), isNull);
    expect(memory.lookup('Mandelmilch'), 24);
  });
}
