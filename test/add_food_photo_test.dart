import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/AddFoodAlertBody/AddFoodAlertBody.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/nutrition/ingredient_memory.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/photo_calorie_service.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';
import 'package:simple_calorie_tracker/widgets/app_text_field.dart';

class _ScriptedCalories extends PhotoCalorieService {
  _ScriptedCalories(this.replies);
  final List<MealEstimate> replies;
  final knownGrams = <int?>[];
  final knownKcalPer100g = <int?>[];
  final knownTotalKcal = <int?>[];
  final extras = <String?>[];
  final notes = <String>[];
  var _index = 0;

  @override
  Future<MealEstimate> estimateFromNote(
    String note, {
    int? knownGrams,
    int? knownKcalPer100g,
    int? knownTotalKcal,
    String? extraContext,
  }) async {
    this.knownGrams.add(knownGrams);
    this.knownKcalPer100g.add(knownKcalPer100g);
    this.knownTotalKcal.add(knownTotalKcal);
    extras.add(extraContext);
    notes.add(note);
    return replies[_index++];
  }
}

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
    expect(find.text('Zurücksetzen'), findsOneWidget);
    expect(find.text('Optional · bleibt im Tagebuch'), findsOneWidget);
    expect(find.text('Schätzen'), findsNothing);
    expect(find.text('Schätzen freischalten'), findsOneWidget);
    expect(find.text('Diesen Text nachschlagen'), findsNothing);
    expect(find.text('Eintragen'), findsOneWidget);
    expect(find.text('Zutat hinzufügen'), findsOneWidget);
    expect(find.text('Zutaten hinzufügen'), findsNothing);
    expect(find.text('Oats'), findsNothing);

    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).focusNode?.hasFocus,
      isTrue,
    );

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
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
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
    expect(find.byIcon(Icons.restaurant_menu_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Was isst du?')).dy,
      lessThan(tester.getTopLeft(find.text('Gewicht')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Zutat').first).dx,
      closeTo(tester.getTopLeft(find.text('Was isst du?')).dx, 16),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '150');
    await tester.enterText(fields.at(3), '380');
    await tester.pump();

    expect(find.text('150'), findsOneWidget);
    expect(find.text('380'), findsOneWidget);
    expect(find.text('g'), findsOneWidget);
    expect(find.text('kcal / 100g'), findsOneWidget);

    final nameBox = tester.getRect(fields.at(1));
    final weightBox = tester.getRect(fields.at(2));
    final energyBox = tester.getRect(fields.at(3));
    expect(nameBox.height, closeTo(weightBox.height, 8));
    expect(weightBox.width, greaterThan(100));
    expect(energyBox.width, greaterThan(100));
    expect(
      tester.getRect(find.text('kcal / 100g')).right,
      closeTo(tester.getRect(find.byType(AppTextField).first).right, 20),
    );
    expect(
      tester.getTopLeft(find.text('150')).dx,
      greaterThan(tester.getTopRight(find.byIcon(Icons.scale_rounded)).dx + 4),
    );
    expect(
      tester.getTopLeft(find.text('380')).dx,
      greaterThan(tester.getTopRight(find.byIcon(Icons.local_fire_department_rounded)).dx + 4),
    );
    expect(tester.getTopLeft(find.text('g')).dx, greaterThan(tester.getTopRight(find.text('150')).dx - 2));
    expect(
      tester.getTopLeft(find.text('kcal / 100g')).dx,
      greaterThan(tester.getTopRight(find.text('380')).dx - 2),
    );
  });

  testWidgets('ingredient metrics keep room inside a zoomed phone dialog', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.de),
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, app) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: app!,
            );
          },
          home: AppDialogCard(
            icon: Icons.restaurant_rounded,
            title: 'Mahlzeit',
            child: AddFoodAlertBody(
              onAddFood: (_) async {},
            ),
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    final titleBox = tester.getRect(fields.first);
    final energyBox = tester.getRect(fields.at(3));
    expect(energyBox.width, greaterThan(titleBox.width * 0.72));
    expect(energyBox.width, greaterThan(180));
    expect(
      tester.getTopLeft(find.text('Gewicht')).dx,
      greaterThan(tester.getTopLeft(find.text('Zutat').first).dx + 8),
    );
  });

  testWidgets('typing energy keeps the field focused after the first digit', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    final energy = find.byType(TextField).at(3);
    await tester.tap(energy);
    await tester.pump();
    await tester.enterText(energy, '3');
    await tester.pump();

    expect(tester.widget<TextField>(energy).focusNode?.hasFocus, isTrue);
    expect(find.text('3'), findsOneWidget);

    await tester.enterText(energy, '38');
    await tester.pump();
    expect(find.text('38'), findsOneWidget);
    expect(tester.widget<TextField>(energy).focusNode?.hasFocus, isTrue);
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

    expect(find.text('Joghurt'), findsWidgets);
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

    expect(find.text('Zutat hinzufügen'), findsOneWidget);
    expect(find.text('Zutaten nachschlagen'), findsOneWidget);
    expect(find.text('Pulver'), findsNothing);
    expect(find.text('Zutat'), findsWidgets);
  });

  testWidgets('ingredients copy the typed name and hide plate weight energy', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Apfel');
    await tester.enterText(fields.at(2), '180');
    await tester.enterText(fields.at(3), '52');
    await tester.pump();

    expect(find.text('Apfel'), findsNWidgets(2));
    expect(find.text('180'), findsWidgets);
    expect(find.text('52'), findsWidgets);
    expect(find.text('94 kcal'), findsOneWidget);
    expect(find.byKey(const Key('ingredient-card')), findsOneWidget);
    expect(find.text('oder Gesamt-kcal'), findsOneWidget);
    expect(find.text('Zutat hinzufügen'), findsOneWidget);
    expect(find.text('Zutaten nachschlagen'), findsOneWidget);
    expect(
      find.text('Die erste Zeile ist, was du oben getippt hast. Weitere Zeilen für ein gemischtes Gericht.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Zutat hinzufügen'));
    await tester.tap(find.text('Zutat hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.text('Zutat'), findsNWidgets(2));
    expect(find.byKey(const Key('ingredient-card')), findsNWidgets(2));
    expect(
      find.text('Die erste Zeile ist, was du oben getippt hast. Weitere Zeilen für ein gemischtes Gericht.'),
      findsNothing,
    );
    expect(find.text('Was isst du?'), findsOneWidget);
    expect(find.text('250'), findsNothing);
    expect(find.text('100'), findsNothing);
  });

  testWidgets('removing the last ingredient leaves only the add and lookup buttons', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    expect(find.text('Zutat'), findsWidgets);
    expect(find.byKey(const Key('remove-ingredient')), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-ingredient')));
    await tester.pump();

    expect(find.text('Zutat'), findsNothing);
    expect(find.byKey(const Key('remove-ingredient')), findsNothing);
    expect(find.text('Zutat hinzufügen'), findsOneWidget);
    expect(find.text('Zutaten nachschlagen'), findsOneWidget);
    expect(find.text('Was isst du?'), findsOneWidget);
  });

  testWidgets('removing the first ingredient keeps what you are eating', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Pizza');
    await tester.pump();
    expect(find.text('Pizza'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('remove-ingredient')));
    await tester.pump();

    expect(find.text('Zutat'), findsNothing);
    expect(find.byKey(const Key('remove-ingredient')), findsNothing);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Was isst du?'), findsOneWidget);
    expect(find.text('Zutat hinzufügen'), findsOneWidget);
    expect(find.text('Zutaten nachschlagen'), findsOneWidget);
  });

  testWidgets('a new ingredient starts without a guessed weight', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    expect(find.text('250'), findsNothing);
    expect(find.text('100'), findsNothing);
    expect(find.text('0'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Reis');
    await tester.pump();
    await tester.ensureVisible(find.text('Zutat hinzufügen'));
    await tester.tap(find.text('Zutat hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.text('250'), findsNothing);
    expect(find.text('100'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('Reis'), findsNWidgets(2));
  });

  testWidgets('adding another ingredient does not claim the new row was not found', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Apfel');
    await tester.enterText(fields.at(2), '180');
    await tester.enterText(fields.at(3), '52');
    await tester.pump();

    await tester.ensureVisible(find.text('Zutat hinzufügen'));
    await tester.tap(find.text('Zutat hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kein Treffer'), findsNothing);
    await tester.enterText(find.byType(TextField).at(4), 'Banane');
    await tester.pump();
    expect(find.textContaining('Kein Treffer'), findsNothing);
    expect(find.text('Banane'), findsOneWidget);
  });

  testWidgets('a field clear button empties the typed value', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '180');
    await tester.pump();
    expect(find.text('180'), findsOneWidget);
    expect(find.byKey(const Key('clear-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-field')));
    await tester.pump();
    expect(find.text('180'), findsNothing);
  });

  testWidgets('a single ingredient stays in sync with what you are eating', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Joghurt');
    await tester.pump();

    expect(find.text('Joghurt'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'Skyr');
    await tester.pump();

    expect(find.text('Skyr'), findsNWidgets(2));
    expect(find.text('Joghurt'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), 'Quark');
    await tester.pump();
    expect(find.text('Quark'), findsNWidgets(2));
    expect(find.text('Skyr'), findsNothing);
  });

  testWidgets('a known ingredient fills energy from past meals', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          ingredientMemory: IngredientMemory.fromMeals([
            const LoggedPlate(name: 'Mandelmilch', kcalPer100g: 24),
          ]),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'Mandelmilch');
    await tester.pump();
    await tester.pump();

    expect(find.text('24'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(3), '18');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Hafermilch');
    await tester.pump();
    expect(find.text('18'), findsOneWidget);
    expect(find.text('24'), findsNothing);
  });

  testWidgets('recalling from the title does not rebuild during build', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          ingredientMemory: IngredientMemory.fromMeals([
            const LoggedPlate(name: 'Mandelmilch', kcalPer100g: 24),
          ]),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Mandelmilch');
    await tester.pump();
    await tester.pump();

    expect(find.text('Mandelmilch'), findsNWidgets(2));
    expect(find.text('24'), findsOneWidget);
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
    expect(find.text('Zutat'), findsNothing);
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

  testWidgets('reset clears typed values and a quick meal chip', (tester) async {
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
        ),
      ),
    );

    expect(find.byKey(const Key('reset-meal')), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Apfel');
    await tester.enterText(fields.at(1), 'Apfel');
    await tester.enterText(fields.at(2), '150');
    await tester.enterText(fields.at(3), '52');
    await tester.pump();

    expect(find.text('Zurücksetzen'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reset-meal')));
    await tester.tap(find.byKey(const Key('reset-meal')));
    await tester.pump();

    expect(find.text('Apfel'), findsNothing);
    expect(find.text('150'), findsNothing);
    expect(find.text('52'), findsNothing);
    expect(find.text('Eintragen'), findsOneWidget);
    expect(find.byKey(const Key('reset-meal')), findsOneWidget);

    await tester.tap(find.text('Oats'));
    await tester.pump();

    expect(find.text('80'), findsOneWidget);
    expect(find.text('380'), findsOneWidget);
    expect(find.textContaining('Teller eintragen'), findsOneWidget);
    expect(find.text('Zurücksetzen'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('reset-meal')));
    await tester.tap(find.byKey(const Key('reset-meal')));
    await tester.pump();

    expect(find.text('Oats'), findsOneWidget);
    expect(find.text('80'), findsNothing);
    expect(find.text('380'), findsNothing);
    expect(find.textContaining('Teller eintragen'), findsNothing);
    expect(find.text('Eintragen'), findsOneWidget);
    expect(find.byKey(const Key('reset-meal')), findsOneWidget);
  });

  testWidgets('reset clears the ingredient name field', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(1), 'Banane');
    await tester.pump();
    expect(find.text('Banane'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('reset-meal')));
    await tester.tap(find.byKey(const Key('reset-meal')));
    await tester.pump();

    expect(find.text('Banane'), findsNothing);
    expect(find.text('Zutat'), findsWidgets);
  });

  testWidgets('long-pressing weight opens a scrub scale', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('number-scrub')), findsNothing);
    await tester.longPress(find.byIcon(Icons.scale_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('number-scrub')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('number-scrub')),
        matching: find.byIcon(Icons.add_rounded),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);
  });

  testWidgets('total kcal is a quiet alternative to kcal per 100g', (tester) async {
    MealDraft? logged;
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (draft) async => logged = draft,
        ),
      ),
    );

    expect(find.text('oder Gesamt-kcal'), findsOneWidget);
    expect(find.text('kcal / 100g'), findsOneWidget);
    expect(find.text('Gesamt'), findsNothing);

    await tester.tap(find.byKey(const Key('total-kcal-mode')));
    await tester.pump();

    expect(find.text('Gesamt'), findsOneWidget);
    expect(find.text('oder kcal / 100g'), findsOneWidget);
    expect(find.text('kcal / 100g'), findsNothing);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Pizza');
    await tester.enterText(fields.at(3), '650');
    await tester.pump();

    expect(find.textContaining('Teller eintragen · 650 kcal'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Teller eintragen'));
    await tester.tap(find.textContaining('Teller eintragen'));
    await tester.pump();

    expect(logged?.name, 'Pizza');
    expect(logged?.kcal, 650);
    expect(logged?.weightInGrams, 100);
    expect(logged?.kcalPer100g, 650);
  });

  testWidgets('total kcal with a weight stores matching density', (tester) async {
    MealDraft? logged;
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (draft) async => logged = draft,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('total-kcal-mode')));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '200');
    await tester.enterText(fields.at(3), '500');
    await tester.pump();

    await tester.ensureVisible(find.textContaining('Teller eintragen'));
    await tester.tap(find.textContaining('Teller eintragen'));
    await tester.pump();

    expect(logged?.kcal, 500);
    expect(logged?.weightInGrams, 200);
    expect(logged?.kcalPer100g, 250);
  });

  testWidgets('reset is hidden while editing a saved meal', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          editMode: true,
          initialName: 'Shake',
          initialGrams: 60,
          initialKcalPer100g: 352,
          onAddFood: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Shake'), findsWidgets);
    expect(find.text('Zurücksetzen'), findsNothing);
  });

  testWidgets('re-estimate does not keep grams and kcal from the first guess', (tester) async {
    const first = MealEstimate(
      mealName: 'Pizza',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Pizza', queryEn: 'pizza', grams: 400),
          matchedName: 'Pizza',
          kcalPer100g: 250,
          source: NutritionSource.usda,
        ),
      ],
    );
    const second = MealEstimate(
      mealName: 'Salat',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Salat', queryEn: 'salad', grams: 180),
          matchedName: 'Salad',
          kcalPer100g: 20,
          source: NutritionSource.usda,
        ),
      ],
    );
    final calories = _ScriptedCalories([first, first, second]);
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          estimateUnlocked: true,
          photoCalories: calories,
        ),
      ),
    );

    const longNote =
        'doppelte pizza mit extra käse und salami vom italienischen imbiss um die ecke';
    await tester.enterText(find.byType(TextField).first, longNote);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.knownGrams, [null]);
    expect(calories.knownKcalPer100g, [null]);
    expect(calories.notes.single, longNote);
    expect(find.text('400'), findsWidgets);
    expect(find.text('250'), findsWidgets);
    expect(find.text('Pizza'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.notes.last, longNote);
    expect(calories.knownGrams, [null, null]);
    expect(calories.knownKcalPer100g, [null, null]);
    expect(calories.extras, [null, null]);

    await tester.enterText(find.byType(TextField).first, 'kleiner Salat');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.knownGrams, [null, null, null]);
    expect(calories.knownKcalPer100g.last, isNull);
    expect(calories.notes.last, 'kleiner Salat');
    expect(find.text('180'), findsWidgets);
    expect(find.text('20'), findsWidgets);
    expect(find.text('400'), findsNothing);
    expect(find.text('250'), findsNothing);
  });

  testWidgets('re-estimate keeps grams and kcal the user typed', (tester) async {
    const first = MealEstimate(
      mealName: 'Oats',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Oats', queryEn: 'oats', grams: 400),
          matchedName: 'Oats',
          kcalPer100g: 250,
          source: NutritionSource.usda,
        ),
      ],
    );
    const second = MealEstimate(
      mealName: 'Oats',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Oats', queryEn: 'oats', grams: 80),
          matchedName: 'Oats',
          kcalPer100g: 380,
          source: NutritionSource.usda,
        ),
      ],
    );
    final calories = _ScriptedCalories([first, second]);
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          estimateUnlocked: true,
          photoCalories: calories,
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Haferflocken');
    await tester.enterText(fields.at(2), '80');
    await tester.enterText(fields.at(3), '380');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.knownGrams, [80]);
    expect(calories.knownKcalPer100g, [380]);
    expect(find.widgetWithText(TextField, '80'), findsWidgets);
    expect(find.widgetWithText(TextField, '380'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Haferflocken mit Milch');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.knownGrams, [80, 80]);
    expect(calories.knownKcalPer100g, [380, 380]);
    expect(calories.notes.last, 'Haferflocken mit Milch');
    expect(find.text('80'), findsWidgets);
    expect(find.text('380'), findsWidgets);
  });

  testWidgets('reset returns the estimate button to Schätzen', (tester) async {
    const estimate = MealEstimate(
      mealName: 'Pizza',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Pizza', queryEn: 'pizza', grams: 200),
          matchedName: 'Pizza',
          kcalPer100g: 250,
          source: NutritionSource.usda,
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          estimateUnlocked: true,
          photoCalories: _ScriptedCalories([estimate]),
        ),
      ),
    );

    expect(find.text('Schätzen'), findsOneWidget);
    expect(find.text('Neu schätzen'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Pizza');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(find.text('Neu schätzen'), findsOneWidget);
    expect(find.text('Schätzen'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('reset-meal')));
    await tester.tap(find.byKey(const Key('reset-meal')));
    await tester.pump();

    expect(find.text('Schätzen'), findsOneWidget);
    expect(find.text('Neu schätzen'), findsNothing);
  });

  testWidgets('the same title and ingredient is sent as a description', (tester) async {
    const estimate = MealEstimate(
      mealName: 'Pizza',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Pizza', queryEn: 'pizza', grams: 200),
          matchedName: 'Pizza',
          kcalPer100g: 250,
          source: NutritionSource.usda,
        ),
      ],
    );
    final calories = _ScriptedCalories([estimate]);
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          estimateUnlocked: true,
          photoCalories: calories,
        ),
      ),
    );

    expect(find.textContaining('Ein Foto zeigt oft nicht alle Zutaten'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Pizza');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.notes, ['Pizza']);
  });

  testWidgets('distinct ingredients are sent as a list, not a dish name', (tester) async {
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
          matchedName: 'Protein powder',
          kcalPer100g: 370,
          source: NutritionSource.usda,
        ),
      ],
    );
    final calories = _ScriptedCalories([estimate]);
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
          estimateUnlocked: true,
          photoCalories: calories,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Shake');
    await tester.pump();
    await tester.ensureVisible(find.text('Zutat hinzufügen'));
    await tester.tap(find.text('Zutat hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(4), 'Mandelmilch');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('estimate-meal')));
    await tester.tap(find.byKey(const Key('estimate-meal')));
    await tester.pumpAndSettle();

    expect(calories.notes, hasLength(1));
    expect(calories.notes.single, contains('Ingredients:'));
    expect(calories.notes.single, contains('Shake'));
    expect(calories.notes.single, contains('Mandelmilch'));
    expect(calories.notes.single, isNot(equals('Shake')));
  });
}
