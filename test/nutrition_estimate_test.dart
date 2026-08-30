import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/nutrition/clarify.dart';
import 'package:simple_calorie_tracker/nutrition/food_sense.dart';
import 'package:simple_calorie_tracker/nutrition/known_foods.dart';
import 'package:simple_calorie_tracker/nutrition/meal_title.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/nutrition_lookup.dart';
import 'package:simple_calorie_tracker/nutrition/open_food_facts_client.dart';
import 'package:simple_calorie_tracker/nutrition/text_meal_parser.dart';
import 'package:simple_calorie_tracker/nutrition/usda_client.dart';

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

  test('a long shake note becomes a short title and keeps the original', () {
    const note =
        'doppelte more protein shake matcha mit chunkey flavour 1 scoop gemacht mit mandelmilch 300ml, und 300ml wasser';
    expect(
      summarizeMealTitle(note: note, modelTitle: 'More Protein Matcha Shake'),
      'More Protein Matcha Shake',
    );
    expect(
      summarizeMealTitle(
        note: note,
        itemNames: ['More Protein Matcha', 'Mandelmilch', 'Wasser'],
      ),
      'More Protein Matcha · Mandelmilch',
    );
    expect(originalMealNote(note: note, title: 'More Protein Matcha Shake'), note);
    expect(summarizeMealTitle(note: 'Joghurt'), 'Joghurt');
    expect(originalMealNote(note: 'Joghurt', title: 'Joghurt'), isNull);
  });

  test('a changed title is the next estimate note, not the first original', () {
    const original =
        'doppelte more protein shake matcha mit chunkey flavour 1 scoop gemacht mit mandelmilch 300ml, und 300ml wasser';
    expect(
      noteForEstimate(
        typed: 'More Protein Matcha Shake',
        originalNote: original,
        appliedTitle: 'More Protein Matcha Shake',
      ),
      original,
    );
    expect(
      noteForEstimate(
        typed: 'kleiner Salat',
        originalNote: original,
        appliedTitle: 'More Protein Matcha Shake',
      ),
      'kleiner Salat',
    );
  });

  test('a typed note can be split into a manual menu', () {
    final items = splitMealNote(
      'doppelte more protein shake matcha 1 scoop gemacht mit mandelmilch 300ml, und 300ml wasser',
    );
    expect(items.length, greaterThanOrEqualTo(2));
    expect(items.last.name.toLowerCase(), contains('wasser'));
    expect(items.last.grams, 300);
    expect(items.first.grams, 60);
    final powder = items.first.copyWith(sense: FoodSense.forKind(FoodKind.powder, items.first.name));
    expect(inferFoodSense(powder).kind, FoodKind.powder);
    expect(inferFoodSense(powder).acceptsKcal(2), isFalse);
    expect(inferFoodSense(powder).acceptsKcal(372), isTrue);
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

  test('Open Food Facts ignores serving-only energy', () {
    expect(
      OpenFoodFactsClient.hitsFromResponse(
        {
          'hits': [
            {
              'code': '1',
              'product_name': 'Matcha tea',
              'nutriments': {'energy-kcal_value': 2},
            },
          ],
        },
        'more protein matcha',
      ),
      isEmpty,
    );
  });

  test('Open Food Facts parses Search-a-licious hits and brand arrays', () {
    final hits = OpenFoodFactsClient.hitsFromResponse(
      {
        'hits': [
          {
            'code': '4255719302563',
            'brands': ['More Nutrition'],
            'product_name': 'More Protein Iced Matcha',
            'nutriments': {'energy-kcal_100g': 372, 'proteins_100g': 66},
          },
        ],
      },
      'more protein matcha',
    );

    expect(hits, hasLength(1));
    expect(hits.single.name, 'More Nutrition More Protein Iced Matcha');
    expect(hits.single.kcalPer100g, 372);
    expect(hits.single.source, NutritionSource.openFoodFacts);
  });

  test('Open Food Facts falls back when the modern search fails', () async {
    final client = OpenFoodFactsClient(
      httpClient: MockClient((request) async {
        if (request.url.host.contains('search.openfoodfacts.org')) {
          throw http.ClientException('Failed to fetch', request.url);
        }
        return http.Response(
          jsonEncode({
            'products': [
              {
                'code': '1',
                'brands': 'More',
                'product_name': 'Protein Iced Matcha Latte',
                'nutriments': {'energy-kcal_100g': 372},
              },
            ],
          }),
          200,
        );
      }),
    );

    final hit = await client.searchBest('more protein matcha');
    expect(hit?.name, 'More Protein Iced Matcha Latte');
    expect(hit?.kcalPer100g, 372);
  });

  test('Open Food Facts returns nothing instead of throwing on fetch failure', () async {
    final client = OpenFoodFactsClient(
      httpClient: MockClient((request) async {
        throw http.ClientException(
          'Failed to fetch',
          Uri.https('world.openfoodfacts.org', '/cgi/search.pl'),
        );
      }),
    );

    expect(await client.search('more protein shake'), isEmpty);
    expect(await client.searchBest('more protein shake'), isNull);
  });

  test('branded lookup continues on USDA when Open Food Facts fetch fails', () async {
    final estimate = await NutritionLookup(
      usda: _AlmondUsda(),
      openFoodFacts: _ThrowingOff(),
    ).ground(
      mealName: 'Shake',
      items: const [
        DetectedFood(
          name: 'More Protein shake',
          queryEn: 'almond milk',
          brandHint: 'More Protein',
          grams: 300,
        ),
      ],
      usdaKey: 'DEMO_KEY',
    );

    expect(estimate.unmatchedItems, isEmpty);
    expect(estimate.items, hasLength(1));
    expect(estimate.items.single.source, NutritionSource.usda);
    expect(estimate.items.single.kcalPer100g, 15);
  });

  test('ambiguous scoop notes ask one high-impact follow-up', () {
    const de = S(AppLang.de);
    const shake = MealEstimate(mealName: 'Shake');

    expect(
      suggestClarification(
        note: 'doppelte more protein shake matcha 1 scoop mit 300ml mandelmilch',
        estimate: shake,
        strings: de,
      )?.id,
      'scoopCount',
    );
    expect(
      suggestClarification(
        note: 'more protein shake 1 scoop mit mandelmilch 300ml',
        estimate: shake,
        strings: de,
      )?.id,
      'scoopWeight',
    );
    expect(
      suggestClarification(
        note: 'more protein shake 1 scoop 30g mit 300ml mandelmilch',
        estimate: shake,
        strings: de,
      ),
      isNull,
    );
    expect(
      suggestClarification(
        note: 'greek pizza 350g',
        estimate: shake,
        strings: de,
      ),
      isNull,
    );
  });

  test('unmatched protein powder can ask powder vs ready drink', () {
    const estimate = MealEstimate(
      mealName: 'Shake',
      unmatchedItems: [
        DetectedFood(
          name: 'More Protein Matcha',
          queryEn: 'protein powder',
          brandHint: 'More Protein',
          grams: 30,
        ),
      ],
    );

    final question = suggestClarification(
      note: 'more protein matcha',
      estimate: estimate,
      strings: const S(AppLang.de),
    );
    expect(question?.id, 'shakeForm');
    expect(question?.options, ['Pulver', 'Fertigshake']);
  });

  test('a model follow-up wins, and a second round stays quiet', () {
    const fromModel = ClarificationQuestion(
      id: 'model',
      question: 'Ungesüßte oder gesüßte Mandelmilch?',
      options: ['Ungesüßt', 'Gesüßt'],
    );
    const estimate = MealEstimate(mealName: 'Shake', clarification: fromModel);

    expect(
      suggestClarification(
        note: 'shake mit mandelmilch',
        estimate: estimate,
        strings: const S(AppLang.de),
        fromModel: fromModel,
      )?.question,
      fromModel.question,
    );
    expect(
      suggestClarification(
        note: '1 scoop protein',
        estimate: estimate,
        strings: const S(AppLang.de),
        fromModel: fromModel,
        alreadyAnswered: true,
      ),
      isNull,
    );
  });

  test('weak model follow-ups are dropped', () {
    expect(ClarificationQuestion.tryParse({'worthAsking': false, 'question': 'Ok?', 'options': ['Ja']}), isNull);
    expect(
      ClarificationQuestion.tryParse({
        'worthAsking': true,
        'question': 'Wie schwer ist ein Scoop?',
        'options': ['25g', '30g', '40g'],
      })?.usable,
      isTrue,
    );
  });

  test('known grams keep the follow-up on the estimate', () {
    const question = ClarificationQuestion(
      id: 'scoopWeight',
      question: 'Scoop?',
      options: ['25g', '30g'],
    );
    const estimate = MealEstimate(
      mealName: 'Shake',
      unmatchedItems: [
        DetectedFood(name: 'Shake', queryEn: 'shake', grams: 400),
      ],
      clarification: question,
    );

    expect(estimate.withKnownGrams(630).clarification?.id, 'scoopWeight');
  });

  test('plain water is 0 kcal and does not call USDA', () async {
    final estimate = await NutritionLookup(
      usda: _FailUsda(),
      openFoodFacts: _EmptyOff(),
    ).ground(
      mealName: 'Water',
      items: const [
        DetectedFood(name: 'Wasser', queryEn: 'water', grams: 300),
      ],
      usdaKey: 'DEMO_KEY',
    );

    expect(estimate.items.single.kcalPer100g, 0);
    expect(estimate.items.single.itemKcal, 0);
    expect(estimate.totalKcal, 0);
  });

  test('lookup keeps the parsed sense and rejects a lookalike hit', () async {
    const powder = FoodSense(
      kind: FoodKind.powder,
      gist: 'dry protein powder, matcha flavor',
      searchAs: 'protein powder',
      notThis: ['brewed tea', 'ready drink'],
    );
    final picked = pickVerifiedHit(
      const [
        NutritionLookupHit(
          name: 'Tea, matcha, brewed',
          kcalPer100g: 2,
          source: NutritionSource.usda,
          score: 80,
        ),
        NutritionLookupHit(
          name: 'Whey protein powder',
          kcalPer100g: 372,
          source: NutritionSource.usda,
          score: 20,
        ),
      ],
      powder,
    );
    expect(picked?.kcalPer100g, 372);

    final estimate = await NutritionLookup(
      usda: _PowderUsda(),
      openFoodFacts: _TeaOff(),
    ).ground(
      mealName: 'Shake',
      items: const [
        DetectedFood(
          name: 'More Protein Matcha doppelte Portion',
          queryEn: 'more protein matcha',
          brandHint: 'More Protein',
          grams: 60,
          sense: powder,
        ),
      ],
      usdaKey: 'DEMO_KEY',
    );

    expect(estimate.items.single.kcalPer100g, 372);
    expect(estimate.items.single.detected.sense?.kind, FoodKind.powder);
    expect(estimate.items.single.grams, 60);
  });

  test('a saved item keeps kind, gist and searchAs', () {
    const item = DetectedFood(
      name: 'More Protein',
      queryEn: 'more protein matcha',
      grams: 60,
      sense: FoodSense(
        kind: FoodKind.powder,
        gist: 'dry protein powder',
        searchAs: 'protein powder',
        notThis: ['brewed tea'],
      ),
    );
    final restored = DetectedFood.fromJson(item.toJson());
    expect(restored.sense?.kind, FoodKind.powder);
    expect(restored.sense?.searchAs, 'protein powder');
    expect(restored.sense?.notThis, ['brewed tea']);
  });

  test('unsweetened almond milk outranks a sweetened USDA name', () {
    expect(
      UsdaClient.scoreFor('Almond milk, unsweetened', 'Foundation', 'almond milk'),
      greaterThan(UsdaClient.scoreFor('Almond milk, vanilla, sweetened', 'Foundation', 'almond milk')),
    );
    expect(
      UsdaClient.scoreFor('Almond milk, unsweetened', 'Foundation', 'almond milk'),
      greaterThan(UsdaClient.scoreFor('Nuts, almonds', 'Foundation', 'almond milk')),
    );
    expect(lookupQueries(const DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300)).first, 'almond milk unsweetened');
  });

  test('editing a line updates grams, kcal and the plate total', () {
    const milk = DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk unsweetened', grams: 300);
    const water = DetectedFood(name: 'Wasser', queryEn: 'water', grams: 300);
    final estimate = MealEstimate(
      mealName: 'Shake',
      items: [
        GroundedFood(detected: milk, matchedName: 'Almond milk', kcalPer100g: 43, source: NutritionSource.usda),
        GroundedFood(detected: water, matchedName: 'Water', kcalPer100g: 42, source: NutritionSource.usda),
      ],
    );

    final fixedWater = estimate.replaceGrounded(1, kcalPer100g: 0);
    expect(fixedWater.items[1].itemKcal, 0);
    expect(fixedWater.items[1].kcalPer100g, 0);
    expect(fixedWater.totalKcal, 129);

    final unsweetened = fixedWater.replaceGrounded(0, kcalPer100g: 15);
    expect(unsweetened.items[0].itemKcal, 45);
    expect(unsweetened.totalKcal, 45);

    final lessMilk = unsweetened.replaceGrounded(0, grams: 200);
    expect(lessMilk.items[0].itemKcal, 30);
    expect(lessMilk.totalGrams, 500);
  });

  test('typing kcal on an unmatched row turns it into a manual item', () {
    const estimate = MealEstimate(
      mealName: 'Shake',
      unmatchedItems: [
        DetectedFood(name: 'More Protein', queryEn: 'protein powder', grams: 30),
      ],
    );
    final next = estimate.replaceUnmatched(0, kcalPer100g: 373);
    expect(next.unmatchedItems, isEmpty);
    expect(next.items.single.source, NutritionSource.manual);
    expect(next.items.single.kcalPer100g, 373);
    expect(next.items.single.itemKcal, 112);
    expect(next.totalKcal, 112);
  });

  test('a meal breakdown survives save and reopen', () {
    const estimate = MealEstimate(
      mealName: 'Shake',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Zerup', queryEn: 'syrup', grams: 20),
          matchedName: 'Syrup',
          kcalPer100g: 333,
          source: NutritionSource.usda,
        ),
      ],
    );
    final restored = MealEstimate.tryDecode(estimate.encode());
    expect(restored?.items.single.detected.name, 'Zerup');
    expect(restored?.items.single.kcalPer100g, 333);
    expect(restored?.items.single.itemKcal, 67);
    expect(MealEstimate.tryDecode(''), isNull);
    expect(MealEstimate.decodeForGrams(estimate.encode(), 40)?.items.single.grams, 40);
  });

  test('generic almond milk uses carton calories without USDA', () async {
    final estimate = await NutritionLookup(
      usda: _FailUsda(),
      openFoodFacts: _EmptyOff(),
    ).ground(
      mealName: 'Shake',
      items: const [
        DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
      ],
      usdaKey: 'DEMO_KEY',
    );

    expect(estimate.items.single.kcalPer100g, 15);
    expect(estimate.items.single.itemKcal, 45);
    expect(estimate.items.single.matchedName, 'Almond milk, unsweetened');
  });

  test('clarification tweaks only the matching line', () {
    const de = S(AppLang.de);
    const powder = GroundedFood(
      detected: DetectedFood(name: 'More Protein', queryEn: 'protein powder', grams: 30),
      matchedName: 'Protein powder',
      kcalPer100g: 370,
      source: NutritionSource.usda,
    );
    const milk = GroundedFood(
      detected: DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
      matchedName: 'Almond milk, unsweetened',
      kcalPer100g: 15,
      source: NutritionSource.usda,
    );
    const estimate = MealEstimate(
      mealName: 'Shake',
      items: [powder, milk],
      clarification: ClarificationQuestion(
        id: 'milkSweetness',
        question: 'Milch?',
        options: ['Ungesüßt', 'Gesüßt'],
      ),
    );

    final sweet = applyClarification(
      estimate: estimate,
      question: estimate.clarification!,
      option: de.sweetenedMilk,
      strings: de,
    );
    expect(sweet!.items[0].kcalPer100g, 370);
    expect(sweet.items[0].grams, 30);
    expect(sweet.items[1].kcalPer100g, 30);
    expect(sweet.items[1].itemKcal, 90);
    expect(sweet.clarification, isNull);

    final scoops = applyClarification(
      estimate: estimate.copyWith(
        clarification: const ClarificationQuestion(
          id: 'scoopCount',
          question: 'Scoops?',
          options: ['1 Scoop', '2 Scoops'],
        ),
      ),
      question: const ClarificationQuestion(
        id: 'scoopCount',
        question: 'Scoops?',
        options: ['1 Scoop', '2 Scoops'],
      ),
      option: de.twoScoops,
      strings: de,
    );
    expect(scoops!.items[0].grams, 60);
    expect(scoops.items[0].kcalPer100g, 370);
    expect(scoops.items[1].kcalPer100g, 15);
  });

  test('unknown clarification still needs a full re-estimate', () {
    const question = ClarificationQuestion(
      id: 'model',
      question: 'Welche Sorte Matcha?',
      options: ['Original', 'Chunky'],
    );
    expect(
      applyClarification(
        estimate: const MealEstimate(mealName: 'Shake', clarification: question),
        question: question,
        option: 'Chunky',
        strings: const S(AppLang.de),
      ),
      isNull,
    );
  });

  test('unspecified plant milk can ask unsweetened vs sweetened', () {
    const estimate = MealEstimate(
      mealName: 'Shake',
      items: [
        GroundedFood(
          detected: DetectedFood(name: 'Mandelmilch', queryEn: 'almond milk', grams: 300),
          matchedName: 'Almond milk',
          kcalPer100g: 43,
          source: NutritionSource.usda,
        ),
      ],
    );
    expect(
      suggestClarification(
        note: 'shake mit mandelmilch 300ml',
        estimate: estimate,
        strings: const S(AppLang.de),
      )?.id,
      'milkSweetness',
    );
  });
}

class _ThrowingOff extends OpenFoodFactsClient {
  @override
  Future<NutritionLookupHit?> searchBest(String query, {FoodSense? sense}) {
    throw http.ClientException(
      'Failed to fetch',
      Uri.https('world.openfoodfacts.org', '/cgi/search.pl'),
    );
  }
}

class _FailUsda extends UsdaClient {
  @override
  Future<NutritionLookupHit?> searchBest(String query, String apiKey, {FoodSense? sense}) {
    throw StateError('USDA should not be queried for $query');
  }
}

class _EmptyOff extends OpenFoodFactsClient {
  @override
  Future<NutritionLookupHit?> searchBest(String query, {FoodSense? sense}) async => null;
}

class _AlmondUsda extends UsdaClient {
  @override
  Future<NutritionLookupHit?> searchBest(String query, String apiKey, {FoodSense? sense}) async {
    return const NutritionLookupHit(
      name: 'Almond milk',
      kcalPer100g: 15,
      source: NutritionSource.usda,
    );
  }
}

class _TeaOff extends OpenFoodFactsClient {
  @override
  Future<NutritionLookupHit?> searchBest(String query, {FoodSense? sense}) async {
    return const NutritionLookupHit(
      name: 'Matcha tea, brewed',
      kcalPer100g: 2,
      source: NutritionSource.openFoodFacts,
      score: 40,
    );
  }
}

class _PowderUsda extends UsdaClient {
  @override
  Future<NutritionLookupHit?> searchBest(String query, String apiKey, {FoodSense? sense}) async {
    final hit = const NutritionLookupHit(
      name: 'Whey protein powder',
      kcalPer100g: 372,
      source: NutritionSource.usda,
    );
    return sense == null ? hit : pickVerifiedHit([hit], sense);
  }
}
