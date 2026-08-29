import 'package:flutter/foundation.dart';

class FavoriteMeal {
  final String id;
  final String name;
  final int kcalPer100g;
  final int weightInGrams;
  final double proteinG;
  final int useCount;
  final int lastUsed;

  const FavoriteMeal({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.weightInGrams,
    this.proteinG = 0,
    this.useCount = 1,
    this.lastUsed = 0,
  });

  int get kcal => ((kcalPer100g * weightInGrams) / 100).round();

  FavoriteMeal copyWith({
    int? useCount,
    int? lastUsed,
    int? weightInGrams,
    double? proteinG,
  }) {
    return FavoriteMeal(
      id: id,
      name: name,
      kcalPer100g: kcalPer100g,
      weightInGrams: weightInGrams ?? this.weightInGrams,
      proteinG: proteinG ?? this.proteinG,
      useCount: useCount ?? this.useCount,
      lastUsed: lastUsed ?? this.lastUsed,
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

  MealDraft({
    required this.kcalPer100g,
    required this.weightInGrams,
    required this.imageBytes,
    required this.didTakeImage,
    this.name = '',
    this.proteinG = 0,
    this.pinFavorite = false,
  });

  int get kcal => ((kcalPer100g * weightInGrams) / 100).round();
}
