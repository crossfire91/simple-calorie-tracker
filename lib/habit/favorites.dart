import 'package:flutter/foundation.dart';

class FavoriteMeal {
  final String id;
  final String name;
  final int kcalPer100g;
  final int weightInGrams;
  final double proteinG;
  final int useCount;
  final int lastUsed;
  final String breakdown;
  final String description;

  const FavoriteMeal({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.weightInGrams,
    this.proteinG = 0,
    this.useCount = 1,
    this.lastUsed = 0,
    this.breakdown = '',
    this.description = '',
  });

  int get kcal => ((kcalPer100g * weightInGrams) / 100).round();

  bool get canLogAgain => weightInGrams > 0 && kcalPer100g > 0;

  FavoriteMeal copyWith({
    int? useCount,
    int? lastUsed,
    int? weightInGrams,
    double? proteinG,
    String? breakdown,
    String? description,
  }) {
    return FavoriteMeal(
      id: id,
      name: name,
      kcalPer100g: kcalPer100g,
      weightInGrams: weightInGrams ?? this.weightInGrams,
      proteinG: proteinG ?? this.proteinG,
      useCount: useCount ?? this.useCount,
      lastUsed: lastUsed ?? this.lastUsed,
      breakdown: breakdown ?? this.breakdown,
      description: description ?? this.description,
    );
  }
}

class MealPhoto {
  final String dateKey;
  final String name;
  final double kcal;
  final String imagePath;
  final Uint8List? imageBytes;

  const MealPhoto({
    required this.dateKey,
    required this.name,
    required this.kcal,
    required this.imagePath,
    this.imageBytes,
  });

  bool get hasFile =>
      (imageBytes != null && imageBytes!.isNotEmpty) ||
      (imagePath.isNotEmpty && !kIsWeb);
}

class MealDraft {
  final int kcalPer100g;
  final int weightInGrams;
  final Uint8List imageBytes;
  final bool didTakeImage;
  final String name;
  final double proteinG;
  final bool pinFavorite;
  final String? breakdown;
  final String? description;

  MealDraft({
    required this.kcalPer100g,
    required this.weightInGrams,
    required this.imageBytes,
    required this.didTakeImage,
    this.name = '',
    this.proteinG = 0,
    this.pinFavorite = false,
    this.breakdown,
    this.description,
  });

  int get kcal => ((kcalPer100g * weightInGrams) / 100).round();
}

class QuickMeals {
  static const limit = 8;

  static List<FavoriteMeal> merge({
    required List<FavoriteMeal> favorites,
    required List<FavoriteMeal> recent,
    int limit = QuickMeals.limit,
  }) {
    final recentByName = <String, FavoriteMeal>{};
    for (final meal in recent) {
      final key = meal.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      recentByName.putIfAbsent(key, () => meal);
    }
    final out = <FavoriteMeal>[];
    final seen = <String>{};
    for (final meal in [...favorites, ...recent]) {
      if (!meal.canLogAgain) continue;
      final key = meal.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      var next = meal;
      if (next.breakdown.trim().isEmpty) {
        final fromRecent = recentByName[key];
        if (fromRecent != null && fromRecent.breakdown.trim().isNotEmpty) {
          next = next.copyWith(
            breakdown: fromRecent.breakdown,
            description: fromRecent.description.trim().isNotEmpty
                ? fromRecent.description
                : next.description,
          );
        }
      }
      out.add(next);
      if (out.length >= limit) break;
    }
    return out;
  }
}
