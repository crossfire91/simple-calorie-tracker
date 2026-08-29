import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';

enum CoachMood {
  morningOpen,
  nextPlate,
  dinner,
  lateSip,
  latePlate,
  proteinPush,
  closed,
  over,
}

class RestSuggestion {
  final String nameEn;
  final String nameDe;
  final int kcal;
  final bool fromFavorite;
  final String? favoriteId;
  final int proteinG;

  const RestSuggestion({
    required this.nameEn,
    required this.nameDe,
    required this.kcal,
    this.fromFavorite = false,
    this.favoriteId,
    this.proteinG = 0,
  });

  String label(bool german) => german ? nameDe : nameEn;

  bool get canLog => favoriteId != null && favoriteId!.isNotEmpty;
}

class RestOfDayPlan {
  final int remaining;
  final CoachMood mood;
  final List<RestSuggestion> suggestions;
  final int proteinGrams;
  final int proteinTarget;

  const RestOfDayPlan({
    required this.remaining,
    required this.mood,
    this.suggestions = const [],
    this.proteinGrams = 0,
    this.proteinTarget = 90,
  });

  bool get over => mood == CoachMood.over;
  bool get closed => mood == CoachMood.closed;
  int get proteinLeft => (proteinTarget - proteinGrams).clamp(0, 999);
  RestSuggestion? get primary => suggestions.isEmpty ? null : suggestions.first;
  List<RestSuggestion> get tapSuggestions =>
      suggestions.where((item) => item.canLog).toList();
}

class RestOfDayMath {
  static const breakfastHour = 11;
  static const eveningHour = 17;
  static const lateHour = 21;

  static const catalog = <RestSuggestion>[
    RestSuggestion(nameEn: 'an apple', nameDe: 'einen Apfel', kcal: 80, proteinG: 0),
    RestSuggestion(nameEn: 'Greek yogurt', nameDe: 'griechischen Joghurt', kcal: 130, proteinG: 10),
    RestSuggestion(nameEn: 'two eggs', nameDe: 'zwei Eier', kcal: 160, proteinG: 13),
    RestSuggestion(nameEn: 'cottage cheese', nameDe: 'Hüttenkäse', kcal: 140, proteinG: 16),
    RestSuggestion(nameEn: 'a chicken plate', nameDe: 'einen Hähnchen-Teller', kcal: 380, proteinG: 30),
    RestSuggestion(nameEn: 'a rice bowl', nameDe: 'eine Reis-Schale', kcal: 450, proteinG: 10),
    RestSuggestion(nameEn: 'a big salad', nameDe: 'einen großen Salat', kcal: 220, proteinG: 8),
    RestSuggestion(nameEn: 'oatmeal', nameDe: 'Haferbrei', kcal: 280, proteinG: 8),
    RestSuggestion(nameEn: 'a banana', nameDe: 'eine Banane', kcal: 100, proteinG: 1),
    RestSuggestion(nameEn: 'dark chocolate', nameDe: 'ein Stück dunkle Schokolade', kcal: 60, proteinG: 1),
  ];

  static RestOfDayPlan plan({
    required double consumed,
    required int budget,
    List<FavoriteMeal> favorites = const [],
    List<LoggedBite> meals = const [],
    double? weightKg,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final hour = clock.hour;
    final remaining = (budget - consumed).round();
    final proteinTarget = ProteinMath.dailyTargetGrams(weightKg);
    final proteinGrams = meals.fold<double>(0, (sum, meal) {
      if (meal.proteinG > 0) return sum + meal.proteinG;
      return sum + ProteinMath.estimateGrams(name: meal.name, kcal: meal.kcal);
    }).round();

    if (remaining < 0) {
      return RestOfDayPlan(
        remaining: remaining.abs(),
        mood: CoachMood.over,
        proteinGrams: proteinGrams,
        proteinTarget: proteinTarget,
      );
    }
    if (remaining <= 25) {
      return RestOfDayPlan(
        remaining: remaining,
        mood: CoachMood.closed,
        proteinGrams: proteinGrams,
        proteinTarget: proteinTarget,
      );
    }

    final proteinLeft = (proteinTarget - proteinGrams).clamp(0, 999);
    final proteinShort = proteinLeft >= 15 && remaining >= 100;
    final emptyMorning = hour < breakfastHour && meals.isEmpty;

    final CoachMood mood;
    if (emptyMorning) {
      mood = CoachMood.morningOpen;
    } else if (hour >= lateHour && remaining < 180) {
      mood = CoachMood.lateSip;
    } else if (hour >= lateHour) {
      mood = CoachMood.latePlate;
    } else if (proteinShort) {
      mood = CoachMood.proteinPush;
    } else if (hour >= eveningHour) {
      mood = CoachMood.dinner;
    } else {
      mood = CoachMood.nextPlate;
    }

    final mealsLeft = hour < 11 ? 3 : hour < 15 ? 2 : 1;
    final targetKcal = (remaining / mealsLeft).round();
    final allowCatalog = !emptyMorning && mood != CoachMood.lateSip;
    final limit = (mood == CoachMood.nextPlate && !proteinShort) ? 2 : 1;

    return RestOfDayPlan(
      remaining: remaining,
      mood: mood,
      proteinGrams: proteinGrams,
      proteinTarget: proteinTarget,
      suggestions: _pick(
        remaining: remaining,
        targetKcal: targetKcal,
        favorites: favorites,
        proteinFirst: proteinShort || mood == CoachMood.proteinPush,
        allowCatalog: allowCatalog,
        limit: limit,
      ),
    );
  }

  static List<RestSuggestion> _pick({
    required int remaining,
    required int targetKcal,
    required List<FavoriteMeal> favorites,
    required bool proteinFirst,
    required bool allowCatalog,
    required int limit,
  }) {
    final fits = <RestSuggestion>[
      for (final fav in favorites)
        if (fav.kcal > 0 && fav.kcal <= remaining)
          RestSuggestion(
            nameEn: fav.name,
            nameDe: fav.name,
            kcal: fav.kcal,
            fromFavorite: true,
            favoriteId: fav.id,
            proteinG: _proteinFor(fav),
          ),
      if (allowCatalog)
        ...catalog.where((item) => item.kcal <= remaining),
    ];

    fits.sort((a, b) {
      if (a.fromFavorite != b.fromFavorite) return a.fromFavorite ? -1 : 1;
      if (proteinFirst) {
        final protein = b.proteinG.compareTo(a.proteinG);
        if (protein != 0) return protein;
      }
      return (a.kcal - targetKcal).abs().compareTo((b.kcal - targetKcal).abs());
    });

    final picked = <RestSuggestion>[];
    final seen = <String>{};
    for (final item in fits) {
      final key = '${item.nameEn.toLowerCase()}-${item.kcal}';
      if (!seen.add(key)) continue;
      picked.add(item);
      if (picked.length == limit) break;
    }
    return picked;
  }

  static int _proteinFor(FavoriteMeal fav) {
    if (fav.proteinG > 0) return fav.proteinG.round();
    return ProteinMath.estimateGrams(name: fav.name, kcal: fav.kcal.toDouble()).round();
  }
}
