import 'dart:convert';

enum NutritionSource { usda, openFoodFacts, web, manual }

enum FoodKind { powder, readyDrink, plantMilk, water, oil, sauce, solid, brewedDrink, unknown }

class FoodSense {
  final FoodKind kind;
  final String gist;
  final List<String> notThis;
  final String searchAs;

  const FoodSense({
    this.kind = FoodKind.unknown,
    this.gist = '',
    this.notThis = const [],
    this.searchAs = '',
  });

  factory FoodSense.fromJson(Map<String, dynamic> json) {
    return FoodSense(
      kind: foodKindFrom(json['kind'] ?? json['form']),
      gist: (json['gist'] ?? '').toString().trim(),
      searchAs: (json['searchAs'] ?? '').toString().trim(),
      notThis: json['notThis'] is List
          ? [
              for (final raw in json['notThis'] as List)
                if (raw.toString().trim().isNotEmpty) raw.toString().trim(),
            ]
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'gist': gist,
        'searchAs': searchAs,
        'notThis': notThis,
      };

  (int, int) get kcalBand {
    switch (kind) {
      case FoodKind.powder:
        return (250, 550);
      case FoodKind.oil:
        return (800, 920);
      case FoodKind.water:
        return (0, 1);
      case FoodKind.plantMilk:
        return (8, 70);
      case FoodKind.readyDrink:
        return (15, 120);
      case FoodKind.brewedDrink:
        return (0, 15);
      case FoodKind.sauce:
        return (15, 450);
      case FoodKind.solid:
        return (15, 700);
      case FoodKind.unknown:
        return (0, 950);
    }
  }

  bool acceptsKcal(int kcal) {
    final band = kcalBand;
    return kcal >= band.$1 && kcal <= band.$2;
  }

  bool acceptsName(String name) {
    final hay = name.toLowerCase();
    for (final reject in notThis) {
      final token = reject.toLowerCase().trim();
      if (token.length < 3) continue;
      if (hay.contains(token)) return false;
      final words = token.split(RegExp(r'\s+')).where((word) => word.length > 3).toList();
      if (words.length >= 2 && words.every(hay.contains)) return false;
    }
    return true;
  }

  factory FoodSense.forKind(FoodKind kind, String name) {
    final label = name.trim().isEmpty ? 'food' : name.trim();
    switch (kind) {
      case FoodKind.powder:
        return FoodSense(
          kind: kind,
          gist: 'dry scoopable powder',
          searchAs: label.toLowerCase().contains('powder') ? label : '$label powder',
          notThis: const ['brewed', 'tea', 'ready to drink', 'beverage'],
        );
      case FoodKind.plantMilk:
        return FoodSense(
          kind: kind,
          gist: 'carton plant milk, not nuts',
          searchAs: label,
          notThis: const ['almonds', 'almond butter', 'flour', 'roasted'],
        );
      case FoodKind.water:
        return const FoodSense(kind: FoodKind.water, gist: 'plain drinking water', searchAs: 'water');
      case FoodKind.oil:
        return FoodSense(kind: kind, gist: 'cooking oil', searchAs: label);
      case FoodKind.readyDrink:
        return FoodSense(
          kind: kind,
          gist: 'ready to drink beverage',
          searchAs: label,
          notThis: const ['powder', 'pulver'],
        );
      case FoodKind.brewedDrink:
        return FoodSense(kind: kind, gist: 'brewed drink', searchAs: label);
      case FoodKind.sauce:
        return FoodSense(kind: kind, gist: 'sauce', searchAs: label);
      case FoodKind.solid:
        return FoodSense(kind: kind, gist: 'solid food', searchAs: label);
      case FoodKind.unknown:
        return FoodSense(kind: kind, gist: label, searchAs: label);
    }
  }

  bool accepts(NutritionLookupHit hit) => acceptsKcal(hit.kcalPer100g) && acceptsName(hit.name);

  int rankBonus(NutritionLookupHit hit) {
    var bonus = 0;
    final hay = hit.name.toLowerCase();
    for (final word in gist.toLowerCase().split(RegExp(r'\s+')).where((word) => word.length > 3)) {
      if (hay.contains(word)) bonus += 6;
    }
    return bonus;
  }
}

FoodKind foodKindFrom(Object? raw) {
  switch (raw?.toString().trim()) {
    case 'powder':
      return FoodKind.powder;
    case 'readyDrink':
    case 'ready_drink':
      return FoodKind.readyDrink;
    case 'plantMilk':
    case 'plant_milk':
      return FoodKind.plantMilk;
    case 'water':
      return FoodKind.water;
    case 'oil':
      return FoodKind.oil;
    case 'sauce':
      return FoodKind.sauce;
    case 'solid':
      return FoodKind.solid;
    case 'brewedDrink':
    case 'brewed_drink':
      return FoodKind.brewedDrink;
    default:
      return FoodKind.unknown;
  }
}

class DetectedFood {
  final String name;
  final String queryEn;
  final String brandHint;
  final int grams;
  final double confidence;
  final List<String> altQueries;
  final FoodSense? sense;

  const DetectedFood({
    required this.name,
    required this.queryEn,
    this.brandHint = '',
    required this.grams,
    this.confidence = 0.6,
    this.altQueries = const [],
    this.sense,
  });

  factory DetectedFood.fromJson(Map<String, dynamic> json) {
    final alts = json['altQueries'];
    final rawSense = json['sense'] ?? json['kind'];
    FoodSense? sense;
    if (rawSense is Map) {
      sense = FoodSense.fromJson(Map<String, dynamic>.from(rawSense));
    } else if (json['kind'] != null || json['gist'] != null || json['searchAs'] != null) {
      sense = FoodSense.fromJson(json);
    }
    return DetectedFood(
      name: (json['name'] ?? '').toString().trim(),
      queryEn: (json['queryEn'] ?? json['searchAs'] ?? json['name'] ?? '').toString().trim(),
      brandHint: (json['brandHint'] ?? '').toString().trim(),
      grams: _asInt(json['grams']) ?? 0,
      confidence: _asDouble(json['confidence']) ?? 0.6,
      altQueries: alts is List
          ? alts.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList()
          : const [],
      sense: sense,
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
    add(sense?.searchAs ?? '');
    add(name);
    add(brandHint);
    for (final alt in altQueries) {
      add(alt);
    }
    return queries;
  }

  DetectedFood copyWith({int? grams, FoodSense? sense, String? name, String? queryEn}) {
    return DetectedFood(
      name: name ?? this.name,
      queryEn: queryEn ?? this.queryEn,
      brandHint: brandHint,
      grams: grams ?? this.grams,
      confidence: confidence,
      altQueries: altQueries,
      sense: sense ?? this.sense,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'queryEn': queryEn,
        'brandHint': brandHint,
        'grams': grams,
        'confidence': confidence,
        'altQueries': altQueries,
        if (sense != null) 'sense': sense!.toJson(),
      };
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
      case NutritionSource.manual:
        return 'Manual';
    }
  }

  GroundedFood copyWith({DetectedFood? detected, int? kcalPer100g}) {
    return GroundedFood(
      detected: detected ?? this.detected,
      matchedName: matchedName,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      source: source,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
    );
  }

  factory GroundedFood.fromJson(Map<String, dynamic> json) {
    return GroundedFood(
      detected: DetectedFood.fromJson(json),
      matchedName: (json['matchedName'] ?? json['name'] ?? '').toString().trim(),
      kcalPer100g: _asInt(json['kcalPer100g']) ?? 0,
      source: NutritionSource.values.firstWhere(
        (item) => item.name == json['source']?.toString(),
        orElse: () => NutritionSource.manual,
      ),
      sourceId: json['sourceId']?.toString(),
      sourceTitle: json['sourceTitle']?.toString(),
      sourceUrl: json['sourceUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        ...detected.toJson(),
        'matchedName': matchedName,
        'kcalPer100g': kcalPer100g,
        'source': source.name,
        if (sourceId != null) 'sourceId': sourceId,
        if (sourceTitle != null) 'sourceTitle': sourceTitle,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      };
}

class ClarificationQuestion {
  final String id;
  final String question;
  final List<String> options;

  const ClarificationQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  static ClarificationQuestion? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['worthAsking'] != true) return null;
    final question = (map['question'] ?? '').toString().trim();
    final options = (map['options'] is List)
        ? (map['options'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty && item.length <= 32)
            .toList()
        : const <String>[];
    if (!isUsable(question: question, options: options)) return null;
    return ClarificationQuestion(id: 'model', question: question, options: options);
  }

  static bool isUsable({required String question, required List<String> options}) {
    if (question.length < 8 || question.length > 160) return false;
    if (options.length < 2 || options.length > 4) return false;
    return options.toSet().length == options.length;
  }

  bool get usable => isUsable(question: question, options: options);
}

class DetectedMeal {
  final String mealName;
  final List<DetectedFood> items;
  final ClarificationQuestion? clarification;
  final String transcript;

  const DetectedMeal({
    required this.mealName,
    required this.items,
    this.clarification,
    this.transcript = '',
  });
}

class MealEstimate {
  final String mealName;
  final List<GroundedFood> items;
  final List<DetectedFood> unmatchedItems;
  final ClarificationQuestion? clarification;

  const MealEstimate({
    required this.mealName,
    this.items = const [],
    this.unmatchedItems = const [],
    this.clarification,
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
          clarification: clarification,
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
      clarification: clarification,
    );
  }

  MealEstimate replaceGrounded(int index, {int? grams, int? kcalPer100g}) {
    if (index < 0 || index >= items.length) return this;
    final item = items[index];
    final nextGrams = (grams ?? item.grams).clamp(1, 100000);
    final next = [...items];
    next[index] = item.copyWith(
      detected: item.detected.copyWith(grams: nextGrams),
      kcalPer100g: (kcalPer100g ?? item.kcalPer100g).clamp(0, 950),
    );
    return copyWith(items: next);
  }

  MealEstimate replaceUnmatched(int index, {int? grams, int? kcalPer100g}) {
    if (index < 0 || index >= unmatchedItems.length) return this;
    final item = unmatchedItems[index];
    final nextGrams = (grams ?? item.grams).clamp(1, 100000);
    if (kcalPer100g == null) {
      final next = [...unmatchedItems];
      next[index] = item.copyWith(grams: nextGrams);
      return copyWith(unmatchedItems: next);
    }
    final per100 = kcalPer100g.clamp(0, 950);
    return copyWith(
      items: [
        ...items,
        GroundedFood(
          detected: item.copyWith(grams: nextGrams),
          matchedName: item.name,
          kcalPer100g: per100,
          source: NutritionSource.manual,
        ),
      ],
      unmatchedItems: [
        ...unmatchedItems.sublist(0, index),
        ...unmatchedItems.sublist(index + 1),
      ],
    );
  }

  List<DetectedFood> get menuItems => [
        ...items.map((item) => item.detected),
        ...unmatchedItems,
      ];

  MealEstimate addUnmatched({String name = '', int grams = 30, FoodSense? sense}) {
    final label = name.trim().isEmpty ? 'Item' : name.trim();
    return copyWith(
      unmatchedItems: [
        ...unmatchedItems,
        DetectedFood(name: label, queryEn: label, grams: grams.clamp(1, 100000), sense: sense),
      ],
    );
  }

  MealEstimate removeMenuLine(int index, {required bool unmatched}) {
    if (unmatched) {
      if (index < 0 || index >= unmatchedItems.length) return this;
      return copyWith(
        unmatchedItems: [
          ...unmatchedItems.sublist(0, index),
          ...unmatchedItems.sublist(index + 1),
        ],
      );
    }
    if (index < 0 || index >= items.length) return this;
    return copyWith(
      items: [
        ...items.sublist(0, index),
        ...items.sublist(index + 1),
      ],
    );
  }

  MealEstimate renameMenuLine(int index, String name, {required bool unmatched}) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return this;
    if (unmatched) {
      if (index < 0 || index >= unmatchedItems.length) return this;
      final next = [...unmatchedItems];
      next[index] = next[index].copyWith(name: cleaned, queryEn: cleaned);
      return copyWith(unmatchedItems: next);
    }
    if (index < 0 || index >= items.length) return this;
    final item = items[index];
    final next = [...items];
    next[index] = item.copyWith(detected: item.detected.copyWith(name: cleaned, queryEn: cleaned));
    return copyWith(items: next);
  }

  MealEstimate setKind(int index, FoodKind kind, {required bool unmatched}) {
    if (unmatched) {
      if (index < 0 || index >= unmatchedItems.length) return this;
      final next = [...unmatchedItems];
      next[index] = next[index].copyWith(sense: FoodSense.forKind(kind, next[index].name));
      return copyWith(unmatchedItems: next);
    }
    if (index < 0 || index >= items.length) return this;
    final item = items[index];
    final next = [...items];
    next[index] = item.copyWith(
      detected: item.detected.copyWith(sense: FoodSense.forKind(kind, item.detected.name)),
    );
    return copyWith(items: next);
  }

  MealEstimate copyWith({
    String? mealName,
    List<GroundedFood>? items,
    List<DetectedFood>? unmatchedItems,
    ClarificationQuestion? clarification,
    bool clearClarification = false,
  }) {
    return MealEstimate(
      mealName: mealName ?? this.mealName,
      items: items ?? this.items,
      unmatchedItems: unmatchedItems ?? this.unmatchedItems,
      clarification: clearClarification ? null : (clarification ?? this.clarification),
    );
  }

  Map<String, dynamic> toJson() => {
        'mealName': mealName,
        'items': [for (final item in items) item.toJson()],
        'unmatchedItems': [for (final item in unmatchedItems) item.toJson()],
      };

  factory MealEstimate.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final unmatched = json['unmatchedItems'];
    return MealEstimate(
      mealName: (json['mealName'] ?? '').toString(),
      items: items is List
          ? [
              for (final raw in items)
                if (raw is Map) GroundedFood.fromJson(Map<String, dynamic>.from(raw)),
            ]
          : const [],
      unmatchedItems: unmatched is List
          ? [
              for (final raw in unmatched)
                if (raw is Map) DetectedFood.fromJson(Map<String, dynamic>.from(raw)),
            ]
          : const [],
    );
  }

  String encode() => jsonEncode(toJson());

  static MealEstimate? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final estimate = MealEstimate.fromJson(Map<String, dynamic>.from(decoded));
      if (estimate.items.isEmpty && estimate.unmatchedItems.isEmpty) return null;
      return estimate;
    } catch (_) {
      return null;
    }
  }

  static MealEstimate? decodeForGrams(String? raw, int grams) {
    final saved = tryDecode(raw);
    if (saved == null) return null;
    if (grams <= 0 || saved.totalGrams == grams) return saved;
    return saved.withKnownGrams(grams);
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

  NutritionLookupHit withScore(int next) {
    return NutritionLookupHit(
      name: name,
      kcalPer100g: kcalPer100g,
      source: source,
      id: id,
      score: next,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
    );
  }
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
