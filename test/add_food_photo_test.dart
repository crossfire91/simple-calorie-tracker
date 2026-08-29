import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/AddFoodAlertBody/AddFoodAlertBody.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return LocaleScope(
    controller: LocaleController(AppLang.de),
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('photo is optional and does not start Gemini by itself', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    expect(find.text('Foto hinzufügen'), findsOneWidget);
    expect(find.text('Optional · bleibt im Tagebuch'), findsOneWidget);
    expect(find.text('Schätzen'), findsNothing);
    expect(find.text('Schätzen freischalten'), findsOneWidget);
    expect(find.text('Diesen Text nachschlagen'), findsNothing);
    expect(find.text('Eintragen'), findsOneWidget);
    expect(find.text('Menü anlegen'), findsOneWidget);
    expect(find.text('Oats'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          quickMeals: const [
            FavoriteMeal(
              id: '1',
              name: 'Oats',
              kcalPer100g: 380,
              weightInGrams: 80,
            ),
          ],
          onPickQuick: (_) {},
        ),
      ),
    );
    expect(find.text('Oats'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          estimateUnlocked: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Schätzen'), findsOneWidget);
    await tester.tap(find.text('Schätzen'));
    await tester.pump();
    expect(find.text('Mahlzeit beschreiben, diktieren oder ein Foto hinzufügen.'), findsOneWidget);
  });

  testWidgets('weight and energy units stay behind the typed number', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    expect(find.text('g'), findsOneWidget);
    expect(find.text('kcal / 100g'), findsOneWidget);

    expect(find.text('Was isst du?'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Was isst du?')).dy,
      lessThan(tester.getTopLeft(find.text('Gewicht')).dy),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '150');
    await tester.enterText(fields.at(2), '380');
    await tester.pump();

    expect(find.text('150'), findsOneWidget);
    expect(find.text('380'), findsOneWidget);
    expect(find.text('g'), findsOneWidget);
    expect(find.text('kcal / 100g'), findsOneWidget);

    final nameBox = tester.getRect(fields.at(0));
    final weightBox = tester.getRect(fields.at(1));
    final energyBox = tester.getRect(fields.at(2));
    expect(nameBox.height, closeTo(weightBox.height, 8));
    expect(weightBox.width, greaterThan(90));
    expect(energyBox.width, greaterThan(90));
    expect(tester.getTopLeft(find.text('g')).dx, greaterThan(tester.getTopRight(find.text('150')).dx - 2));
    expect(
      tester.getTopLeft(find.text('kcal / 100g')).dx,
      greaterThan(tester.getTopRight(find.text('380')).dx - 2),
    );
  });

  testWidgets('favorite draft fills weight, energy, name and photo', (tester) async {
    const png = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          initialName: 'Joghurt',
          initialKcalPer100g: 80,
          initialGrams: 150,
          initialImage: Uint8List.fromList(png),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Joghurt'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('Foto hinzufügen'), findsNothing);
    expect(find.textContaining('Teller eintragen'), findsOneWidget);
  });

  testWidgets('quick meal chip prefills the form instead of logging', (tester) async {
    FavoriteMeal? picked;
    MealDraft? logged;
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (draft) async => logged = draft,
          quickMeals: const [
            FavoriteMeal(
              id: '1',
              name: 'Oats',
              kcalPer100g: 380,
              weightInGrams: 80,
            ),
          ],
          onPickQuick: (meal) => picked = meal,
        ),
      ),
    );

    await tester.tap(find.text('Oats'));
    await tester.pump();

    expect(picked?.id, '1');
    expect(logged, isNull);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('380'), findsOneWidget);
    expect(find.textContaining('Teller eintragen'), findsOneWidget);
  });

  testWidgets('a manual menu can be built without estimating', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          initialName: 'Shake mit Mandelmilch und Wasser',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Menü anlegen'));
    await tester.pump();

    expect(find.text('Zutat hinzufügen'), findsOneWidget);
    expect(find.text('Zutaten nachschlagen'), findsOneWidget);
    expect(find.text('Pulver'), findsNothing);
    expect(find.text('Name'), findsWidgets);
  });

  testWidgets('long original note stays folded under a short title', (tester) async {
    const note =
        'doppelte more protein shake matcha mit chunkey flavour 1 scoop gemacht mit mandelmilch 300ml, und 300ml wasser';
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          editMode: true,
          initialName: 'More Protein Matcha Shake',
          initialDescription: note,
          initialGrams: 630,
          initialKcalPer100g: 40,
          onAddFood: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('More Protein Matcha Shake'), findsOneWidget);
    expect(find.text('Titel'), findsOneWidget);
    expect(find.text('Originalbeschreibung'), findsOneWidget);
    expect(find.text(note), findsNothing);

    await tester.tap(find.text('Originalbeschreibung'));
    await tester.pump();
    expect(find.text(note), findsOneWidget);
  });

  testWidgets('edit mode can fix one ingredient and save the meal', (tester) async {
    MealDraft? saved;
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          editMode: true,
          initialName: 'Shake',
          initialGrams: 60,
          initialKcalPer100g: 352,
          initialEstimate: const MealEstimate(
            mealName: 'Shake',
            items: [
              GroundedFood(
                detected: DetectedFood(name: 'Protein', queryEn: 'protein powder', grams: 30),
                matchedName: 'Powder',
                kcalPer100g: 370,
                source: NutritionSource.usda,
              ),
              GroundedFood(
                detected: DetectedFood(name: 'Zerup', queryEn: 'syrup', grams: 30),
                matchedName: 'Syrup',
                kcalPer100g: 333,
                source: NutritionSource.usda,
              ),
            ],
          ),
          onAddFood: (draft) async => saved = draft,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Zerup'), findsOneWidget);
    expect(find.text('100 kcal'), findsOneWidget);
    expect(find.textContaining('Änderungen speichern'), findsOneWidget);
    expect(find.text('Oats'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '333'), '100');
    await tester.pump();
    expect(find.text('30 kcal'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Änderungen speichern'));
    await tester.tap(find.textContaining('Änderungen speichern'));
    await tester.pump();

    expect(saved?.kcal, 141);
    expect(MealEstimate.tryDecode(saved?.breakdown)?.items.last.kcalPer100g, 100);
  });

  testWidgets('favorite draft shows the saved menu list', (tester) async {
    const estimate = MealEstimate(
      mealName: 'Shake',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
          matchedName: 'Almond milk',
          kcalPer100g: 15,
          source: NutritionSource.usda,
        ),
        GroundedFood(
          detected: DetectedFood(name: 'Protein', queryEn: 'protein powder', grams: 30),
          matchedName: 'Powder',
          kcalPer100g: 370,
          source: NutritionSource.usda,
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          initialName: 'Shake',
          initialKcalPer100g: estimate.kcalPer100g,
          initialGrams: estimate.totalGrams,
          initialEstimate: estimate,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mandelmilch'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('45 kcal'), findsOneWidget);
    expect(find.text('111 kcal'), findsOneWidget);
    expect(find.text('Zutat hinzufügen'), findsNothing);
    expect(find.text('Name'), findsNothing);
  });

  testWidgets('favorite chip restores the saved menu list', (tester) async {
    const estimate = MealEstimate(
      mealName: 'Shake',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
          matchedName: 'Almond milk',
          kcalPer100g: 15,
          source: NutritionSource.usda,
        ),
        GroundedFood(
          detected: DetectedFood(name: 'Protein', queryEn: 'protein powder', grams: 30),
          matchedName: 'Powder',
          kcalPer100g: 370,
          source: NutritionSource.usda,
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          quickMeals: [
            FavoriteMeal(
              id: '1',
              name: 'Shake',
              kcalPer100g: estimate.kcalPer100g,
              weightInGrams: estimate.totalGrams,
              breakdown: estimate.encode(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mandelmilch'), findsNothing);

    await tester.tap(find.text('Shake'));
    await tester.pump();

    expect(find.text('Mandelmilch'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
  });
}
