import 'package:simple_calorie_tracker/nutrition/models.dart';

bool isPlainWaterItem(DetectedFood item) {
  return isPlainWaterName(item.queryEn) || isPlainWaterName(item.name);
}

bool isPlainWaterName(String raw) {
  final hay = _norm(raw);
  if (hay.isEmpty || isFlavoredWaterName(hay)) return false;
  if (hay == 'water tap' || hay == 'tap water' || hay == 'drinking water') return true;
  return RegExp(
    r'^(?:tap |municipal |drinking |sparkling |carbonated |mineral |soda |leitungs)?'
    r'(water|wasser|eau|agua|mineralwasser)$',
  ).hasMatch(hay);
}

bool isFlavoredWaterName(String raw) {
  final hay = _norm(raw);
  return hay.contains('coconut') ||
      hay.contains('kokos') ||
      hay.contains('tonic') ||
      hay.contains('vitamin') ||
      hay.contains('melon') ||
      hay.contains('rose') ||
      hay.contains('juice') ||
      hay.contains('saft') ||
      hay.contains('flavor') ||
      hay.contains('flavour');
}

bool isWaterQuery(String raw) {
  final hay = _norm(raw);
  return RegExp(r'\b(water|wasser|eau|agua)\b').hasMatch(hay) && !isFlavoredWaterName(hay);
}

bool isPlantMilkQuery(String raw) {
  final hay = _norm(raw);
  final nut = hay.contains('almond') ||
      hay.contains('mandel') ||
      hay.contains('oat') ||
      hay.contains('hafer') ||
      hay.contains('soy') ||
      hay.contains('soja') ||
      hay.contains('soj');
  final milk = hay.contains('milk') || hay.contains('milch');
  return nut && milk;
}

bool mentionsSweetness(String raw) {
  final hay = _norm(raw);
  return mentionsSweetenedOnly(hay) ||
      hay.contains('unsweetened') ||
      hay.contains('ungesüß') ||
      hay.contains('ungesuess');
}

bool mentionsSweetenedOnly(String raw) {
  final hay = _norm(raw);
  if (hay.contains('unsweetened') || hay.contains('ungesüß') || hay.contains('ungesuess')) {
    return false;
  }
  return hay.contains('sweet') ||
      hay.contains('süß') ||
      hay.contains('suess') ||
      hay.contains('vanilla') ||
      hay.contains('vanille') ||
      hay.contains('chocolate') ||
      hay.contains('schoko');
}

/// Carton almond/oat/soy milk, not nuts or cooking cream.
int? typicalPlantMilkKcalPer100g(DetectedFood item, {bool? sweetened}) {
  final hay = '${item.queryEn} ${item.name}';
  if (!isPlantMilkQuery(hay)) return null;
  final treatSweet = sweetened ?? mentionsSweetenedOnly(hay);
  if (hay.contains('almond') || hay.contains('mandel')) return treatSweet ? 30 : 15;
  if (hay.contains('oat') || hay.contains('hafer')) return treatSweet ? 58 : 40;
  if (hay.contains('soy') || hay.contains('soja') || hay.contains('soj')) {
    return treatSweet ? 45 : 33;
  }
  return treatSweet ? 35 : 20;
}

String plantMilkLabel(DetectedFood item, {bool? sweetened}) {
  final kcal = typicalPlantMilkKcalPer100g(item, sweetened: sweetened) ?? 15;
  final hay = '${item.queryEn} ${item.name}'.toLowerCase();
  final kind = hay.contains('oat') || hay.contains('hafer')
      ? 'Oat milk'
      : hay.contains('soy') || hay.contains('soja')
          ? 'Soy milk'
          : 'Almond milk';
  return kcal >= 28 ? '$kind, sweetened' : '$kind, unsweetened';
}

bool prefersUnsweetenedPlantMilk(DetectedFood item) {
  final hay = '${item.queryEn} ${item.name}';
  return isPlantMilkQuery(hay) && !mentionsSweetness(hay);
}

List<String> lookupQueries(DetectedFood item) {
  final queries = [...item.searchQueries];
  if (prefersUnsweetenedPlantMilk(item)) {
    final base = item.queryEn.isNotEmpty ? item.queryEn : item.name;
    final unsweetened = '$base unsweetened';
    if (!queries.any((query) => query.toLowerCase() == unsweetened.toLowerCase())) {
      queries.insert(0, unsweetened);
    }
  }
  return queries;
}

NutritionLookupHit? knownHitFor(DetectedFood item) {
  if (isPlainWaterItem(item)) {
    return const NutritionLookupHit(
      name: 'Water',
      kcalPer100g: 0,
      source: NutritionSource.usda,
      score: 200,
    );
  }
  if (item.brandHint.isNotEmpty) return null;
  final milkKcal = typicalPlantMilkKcalPer100g(item);
  if (milkKcal == null) return null;
  return NutritionLookupHit(
    name: plantMilkLabel(item),
    kcalPer100g: milkKcal,
    source: NutritionSource.usda,
    score: 180,
  );
}

String _norm(String raw) => raw.toLowerCase().trim();
