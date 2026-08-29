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
      final hit = await _databaseHit(item, usdaKey);
      if (hit == null) {
        missed.add(item);
        continue;
      }
      grounded.add(_toFood(item, hit));
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
        ),
        usdaKey,
      );
      if (retry != null) return _toFood(item, retry);
    }

    final kcal = hint?.kcalPer100g;
    if (kcal == null || kcal <= 0 || kcal > 950) return null;

    return GroundedFood(
      detected: item,
      matchedName: hint?.sourceTitle ?? item.name,
      kcalPer100g: kcal,
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
    if (item.brandHint.isNotEmpty) {
      final branded = await _openFoodFacts.searchBest(
        [item.brandHint, item.queryEn.isNotEmpty ? item.queryEn : item.name].join(' ').trim(),
      );
      if (branded != null) return branded;
    }

    for (final query in item.searchQueries) {
      final usda = await _usda.searchBest(query, usdaKey);
      if (usda != null) return usda;
      final off = await _openFoodFacts.searchBest(query);
      if (off != null) return off;
    }
    return null;
  }
}
