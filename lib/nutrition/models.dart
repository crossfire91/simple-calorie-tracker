enum NutritionSource { usda, openFoodFacts, web }

class DetectedFood {
  final String name;
  final String queryEn;
  final String brandHint;
  final int grams;
  final double confidence;
  final List<String> altQueries;

  const DetectedFood({
    required this.name,
    required this.queryEn,
    this.brandHint = '',
    required this.grams,
    this.confidence = 0.6,
    this.altQueries = const [],
  });

  factory DetectedFood.fromJson(Map<String, dynamic> json) {
    final alts = json['altQueries'];
    return DetectedFood(
      name: (json['name'] ?? '').toString().trim(),
      queryEn: (json['queryEn'] ?? json['name'] ?? '').toString().trim(),
      brandHint: (json['brandHint'] ?? '').toString().trim(),
      grams: _asInt(json['grams']) ?? 0,
      confidence: _asDouble(json['confidence']) ?? 0.6,
      altQueries: alts is List
          ? alts.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList()
          : const [],
    );
  }

  List<String> get searchQueries {
    final seen = <String>{};
    final queries = <String>[];
    void add(String raw) {
      final cleaned = raw.trim();
      if (cleaned.length < 2) return;
      final key = cleaned.toLowerCase();
      if (!seen.add(key)) return;
      queries.add(cleaned);
    }

    add(queryEn);
    add(name);
    add(brandHint);
    for (final alt in altQueries) {
      add(alt);
    }
    return queries;
  }

  DetectedFood copyWith({int? grams}) {
    return DetectedFood(
      name: name,
      queryEn: queryEn,
      brandHint: brandHint,
      grams: grams ?? this.grams,
      confidence: confidence,
      altQueries: altQueries,
    );
  }
}

class GroundedFood {
  final DetectedFood detected;
  final String matchedName;
  final int kcalPer100g;
  final NutritionSource source;
  final String? sourceId;
  final String? sourceTitle;
  final String? sourceUrl;

  const GroundedFood({
    required this.detected,
    required this.matchedName,
    required this.kcalPer100g,
    required this.source,
    this.sourceId,
    this.sourceTitle,
    this.sourceUrl,
  });

  int get grams => detected.grams;

  int get itemKcal => (grams * kcalPer100g / 100).round();

  bool get unverified => source == NutritionSource.web;

  String get sourceLabel {
    switch (source) {
      case NutritionSource.usda:
        return 'USDA';
      case NutritionSource.openFoodFacts:
        return 'Open Food Facts';
      case NutritionSource.web:
        return 'Web';
    }
  }

  GroundedFood copyWith({DetectedFood? detected}) {
    return GroundedFood(
      detected: detected ?? this.detected,
      matchedName: matchedName,
      kcalPer100g: kcalPer100g,
      source: source,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
    );
  }
}

class MealEstimate {
  final String mealName;
  final List<GroundedFood> items;
  final List<DetectedFood> unmatchedItems;

  const MealEstimate({
    required this.mealName,
    this.items = const [],
    this.unmatchedItems = const [],
  });

  List<String> get unmatched => unmatchedItems.map((item) => item.name).toList();

  int get totalGrams =>
      items.fold(0, (sum, item) => sum + item.grams) +
      unmatchedItems.fold(0, (sum, item) => sum + item.grams);

  int get totalKcal => items.fold(0, (sum, item) => sum + item.itemKcal);

  int get kcalPer100g {
    final grams = totalGrams;
    if (grams <= 0) return 0;
    return ((totalKcal / grams) * 100).round();
  }

  bool get hasWebSource => items.any((item) => item.unverified);

  String get sourcesLabel {
    final labels = items.map((item) => item.sourceLabel).toSet().toList()
      ..sort();
    return labels.join(' · ');
  }

  /// Keep the user's known plate weight; only the mix of items is scaled.
  MealEstimate withKnownGrams(int knownGrams) {
    if (knownGrams <= 0) return this;
    final current = totalGrams;
    if (current <= 0) {
      if (unmatchedItems.length == 1 && items.isEmpty) {
        return MealEstimate(
          mealName: mealName,
          unmatchedItems: [unmatchedItems.first.copyWith(grams: knownGrams)],
        );
      }
      return this;
    }
    if (current == knownGrams) return this;

    final all = [
      ...items.map((item) => item.grams),
      ...unmatchedItems.map((item) => item.grams),
    ];
    final scaled = _distribute(all, knownGrams);
    var index = 0;
    return MealEstimate(
      mealName: mealName,
      items: [
        for (final item in items) item.copyWith(detected: item.detected.copyWith(grams: scaled[index++])),
      ],
      unmatchedItems: [
        for (final item in unmatchedItems) item.copyWith(grams: scaled[index++]),
      ],
    );
  }
}

List<int> _distribute(List<int> parts, int target) {
  final sum = parts.fold<int>(0, (total, part) => total + part);
  if (sum <= 0 || parts.isEmpty) return parts;
  final scaled = [for (final part in parts) ((part * target) / sum).round()];
  var drift = target - scaled.fold<int>(0, (total, part) => total + part);
  scaled[scaled.length - 1] = (scaled.last + drift).clamp(1, 100000);
  return scaled;
}

class NutritionLookupHit {
  final String name;
  final int kcalPer100g;
  final NutritionSource source;
  final String? id;
  final int score;
  final String? sourceTitle;
  final String? sourceUrl;

  const NutritionLookupHit({
    required this.name,
    required this.kcalPer100g,
    required this.source,
    this.id,
    this.score = 0,
    this.sourceTitle,
    this.sourceUrl,
  });
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
