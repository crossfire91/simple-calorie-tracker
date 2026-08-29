import 'package:simple_calorie_tracker/nutrition/known_foods.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';

/// What the parser understood the item to *be*. Lookups must honor this.
FoodSense inferFoodSense(DetectedFood item) {
  final given = item.sense;
  if (given != null && given.kind != FoodKind.unknown) return given;

  if (isPlainWaterItem(item)) {
    return const FoodSense(
      kind: FoodKind.water,
      gist: 'plain drinking water',
      searchAs: 'water',
    );
  }

  final hay = '${item.queryEn} ${item.name} ${item.brandHint}'.toLowerCase();
  if (isPlantMilkQuery(hay)) {
    return FoodSense(
      kind: FoodKind.plantMilk,
      gist: 'carton plant milk, not nuts',
      searchAs: item.queryEn.isNotEmpty ? item.queryEn : item.name,
      notThis: const ['almonds', 'almond butter', 'flour', 'roasted'],
    );
  }
  if (RegExp(r'\b(oil|öl|olive oil)\b').hasMatch(hay)) {
    return FoodSense(
      kind: FoodKind.oil,
      gist: 'cooking oil',
      searchAs: item.queryEn.isNotEmpty ? item.queryEn : item.name,
    );
  }
  if (_looksLikeDryPowder(hay, item.grams)) {
    final search = item.queryEn.toLowerCase().contains('powder') ||
            item.queryEn.toLowerCase().contains('pulver')
        ? item.queryEn
        : '${item.queryEn.isNotEmpty ? item.queryEn : item.name} powder';
    return FoodSense(
      kind: FoodKind.powder,
      gist: 'dry scoopable powder, not a brewed drink',
      searchAs: search.trim(),
      notThis: const ['brewed', 'tea', 'ready to drink', 'beverage'],
    );
  }

  return FoodSense(
    kind: given?.kind ?? FoodKind.unknown,
    gist: given?.gist.isNotEmpty == true ? given!.gist : item.name,
    searchAs: given?.searchAs.isNotEmpty == true
        ? given!.searchAs
        : (item.queryEn.isNotEmpty ? item.queryEn : item.name),
    notThis: given?.notThis ?? const [],
  );
}

bool _looksLikeDryPowder(String hay, int grams) {
  if (RegExp(r'\b(powder|pulver|whey|scoop|isolate|casein)\b').hasMatch(hay)) {
    return true;
  }
  if (!RegExp(r'\bprotein\b').hasMatch(hay)) return false;
  if (grams < 20 || grams > 90) return false;
  return !RegExp(r'\b(ready|fertig|drink|beverage|tea|milk|milch)\b').hasMatch(hay);
}

/// Keep the first hit that still matches what we understood. No extra API call.
NutritionLookupHit? pickVerifiedHit(List<NutritionLookupHit> hits, FoodSense sense) {
  if (hits.isEmpty) return null;
  final ranked = [
    for (final hit in hits)
      if (sense.accepts(hit)) hit.withScore(hit.score + sense.rankBonus(hit)),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return ranked.isEmpty ? null : ranked.first;
}
