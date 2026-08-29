import 'package:simple_calorie_tracker/nutrition/food_sense.dart';
import 'package:simple_calorie_tracker/nutrition/known_foods.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/open_food_facts_client.dart';
import 'package:simple_calorie_tracker/nutrition/usda_client.dart';
import 'package:simple_calorie_tracker/nutrition/web_grounding.dart';

class NutritionLookup {
  NutritionLookup({
    UsdaClient? usda,
    OpenFoodFactsClient? openFoodFacts,
    WebGrounding? web,
  })  : _usda = usda ?? UsdaClient(),
        _openFoodFacts = openFoodFacts ?? OpenFoodFactsClient(),
        _web = web ?? WebGrounding();

  final UsdaClient _usda;
  final OpenFoodFactsClient _openFoodFacts;
  final WebGrounding _web;

  Future<MealEstimate> ground({
    required String mealName,
    required List<DetectedFood> items,
    required String usdaKey,
    String? geminiKey,
  }) async {
    final grounded = <GroundedFood>[];
    final missed = <DetectedFood>[];

    for (final item in items) {
      final understood = item.copyWith(sense: inferFoodSense(item));
      final hit = await _databaseHit(understood, usdaKey);
      if (hit == null) {
        missed.add(understood);
        continue;
      }
      grounded.add(_toFood(understood, hit));
    }

    if (missed.isNotEmpty && geminiKey != null && geminiKey.isNotEmpty) {
      try {
        final hints = await _web.lookup(items: missed, apiKey: geminiKey);
        final stillMissed = <DetectedFood>[];
        for (final item in missed) {
          final recovered = await _recoverFromWeb(item, usdaKey, hints);
          if (recovered == null) {
            stillMissed.add(item);
          } else {
            grounded.add(recovered);
          }
        }
        missed
          ..clear()
          ..addAll(stillMissed);
      } catch (_) {
        // Keep database misses; user can type energy.
      }
    }

    return MealEstimate(
      mealName: mealName,
      items: grounded,
      unmatchedItems: missed,
    );
  }

  Future<GroundedFood?> _recoverFromWeb(
    DetectedFood item,
    String usdaKey,
    Map<String, WebNutritionHint> hints,
  ) async {
    final hint = _hintFor(item, hints);

    final generic = hint?.genericQuery?.trim();
    if (generic != null && generic.isNotEmpty) {
      final retry = await _databaseHit(
        DetectedFood(
          name: item.name,
          queryEn: generic,
          brandHint: item.brandHint,
          grams: item.grams,
          altQueries: item.altQueries,
          sense: item.sense,
        ),
        usdaKey,
      );
      if (retry != null) return _toFood(item, retry);
    }

    final kcal = hint?.kcalPer100g;
    if (kcal == null || kcal < 0 || kcal > 950) return null;
    final typical = typicalPlantMilkKcalPer100g(item);
    final sane = typical != null && kcal > 65 ? typical : kcal;
    if (!inferFoodSense(item).acceptsKcal(sane)) return null;

    return GroundedFood(
      detected: item,
      matchedName: sane == typical ? plantMilkLabel(item) : (hint?.sourceTitle ?? item.name),
      kcalPer100g: sane,
      source: NutritionSource.web,
      sourceTitle: hint?.sourceTitle,
      sourceUrl: hint?.sourceUrl,
    );
  }

  WebNutritionHint? _hintFor(DetectedFood item, Map<String, WebNutritionHint> hints) {
    for (final key in [item.name, item.queryEn, ...item.altQueries]) {
      final hit = hints[key.toLowerCase()];
      if (hit != null) return hit;
    }
    if (hints.length == 1) return hints.values.first;
    return null;
  }

  GroundedFood _toFood(DetectedFood item, NutritionLookupHit hit) {
    return GroundedFood(
      detected: item,
      matchedName: hit.name,
      kcalPer100g: hit.kcalPer100g,
      source: hit.source,
      sourceId: hit.id,
      sourceTitle: hit.sourceTitle,
      sourceUrl: hit.sourceUrl,
    );
  }

  Future<NutritionLookupHit?> _databaseHit(DetectedFood item, String usdaKey) async {
    final known = knownHitFor(item);
    if (known != null) return known;
    final sense = inferFoodSense(item);

    if (item.brandHint.isNotEmpty) {
      final branded = _sanePlantMilk(
        item,
        await _offHit(
          [item.brandHint, sense.searchAs.isNotEmpty ? sense.searchAs : item.queryEn].join(' ').trim(),
          sense,
        ),
      );
      if (branded != null && sense.accepts(branded)) return branded;
    }

    for (final query in lookupQueries(item.copyWith(sense: sense))) {
      final usda = _sanePlantMilk(item, await _usdaHit(query, usdaKey, sense));
      if (usda != null && sense.accepts(usda)) return usda;
      final off = _sanePlantMilk(item, await _offHit(query, sense));
      if (off != null && sense.accepts(off)) return off;
    }
    return null;
  }

  /// Carton drinks are ~15–60 kcal/100g. 80+ is almost always nuts, butter, or a serving-size bug.
  NutritionLookupHit? _sanePlantMilk(DetectedFood item, NutritionLookupHit? hit) {
    if (hit == null) return null;
    if (!isPlantMilkQuery('${item.queryEn} ${item.name} ${hit.name}')) return hit;
    if (hit.kcalPer100g <= 65) return hit;
    final typical = typicalPlantMilkKcalPer100g(item);
    if (typical == null) return hit;
    return NutritionLookupHit(
      name: plantMilkLabel(item),
      kcalPer100g: typical,
      source: hit.source,
      score: hit.score,
    );
  }

  Future<NutritionLookupHit?> _offHit(String query, [FoodSense? sense]) async {
    try {
      return await _openFoodFacts.searchBest(query, sense: sense);
    } catch (_) {
      return null;
    }
  }

  Future<NutritionLookupHit?> _usdaHit(String query, String usdaKey, [FoodSense? sense]) async {
    try {
      return await _usda.searchBest(query, usdaKey, sense: sense);
    } catch (_) {
      return null;
    }
  }
}
