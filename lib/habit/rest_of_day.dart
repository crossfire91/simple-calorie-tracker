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
  final int servings;

  const RestSuggestion({
    required this.nameEn,
    required this.nameDe,
    required this.kcal,
    this.fromFavorite = false,
    this.favoriteId,
    this.proteinG = 0,
    this.servings = 1,
  });

  String label(bool german) => german ? nameDe : nameEn;

  bool get canLog => favoriteId != null && favoriteId!.isNotEmpty;
  int get lineKcal => kcal * servings;

  RestSuggestion withServings(int next) => RestSuggestion(
        nameEn: nameEn,
        nameDe: nameDe,
        kcal: kcal,
        fromFavorite: fromFavorite,
        favoriteId: favoriteId,
        proteinG: proteinG,
        servings: next,
      );
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
  int get filledKcal =>
      suggestions.fold(0, (sum, item) => sum + item.lineKcal);
  int get leftoverAfterPlan => (remaining - filledKcal).clamp(0, remaining);
  bool get hasFill => suggestions.isNotEmpty;
  bool get fromFavorites => suggestions.any((item) => item.fromFavorite);

  bool get namesAPlate {
    final item = primary;
    if (item == null) return false;
    if (mood == CoachMood.dinner || mood == CoachMood.latePlate) {
      final floor = (remaining * 0.3).round().clamp(120, remaining);
      return item.kcal >= floor;
    }
    return true;
  }
}

class RestOfDayMath {
  static const breakfastHour = 11;
  static const eveningHour = 17;
  static const lateHour = 21;
  static const maxLines = 6;
  static const maxServings = 2;
  static const minItemKcal = 50;
  static const stopLeftover = 80;

  static RestOfDayPlan plan({
    required double consumed,
    required int budget,
    List<FavoriteMeal> favorites = const [],
    List<FavoriteMeal> recent = const [],
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

    final emptyMorning = hour < breakfastHour && meals.isEmpty;

    final CoachMood mood;
    if (emptyMorning) {
      mood = CoachMood.morningOpen;
    } else if (hour >= lateHour && remaining < 180) {
      mood = CoachMood.lateSip;
    } else if (hour >= lateHour) {
      mood = CoachMood.latePlate;
    } else if (hour >= eveningHour) {
      mood = CoachMood.dinner;
    } else {
      mood = CoachMood.nextPlate;
    }

    return RestOfDayPlan(
      remaining: remaining,
      mood: mood,
      proteinGrams: proteinGrams,
      proteinTarget: proteinTarget,
      suggestions: mood == CoachMood.lateSip
          ? const []
          : fillKnown(
              remaining: remaining,
              favorites: favorites,
              recent: recent,
            ),
    );
  }

  static List<RestSuggestion> fillKnown({
    required int remaining,
    required List<FavoriteMeal> favorites,
    List<FavoriteMeal> recent = const [],
  }) {
    if (remaining < minItemKcal) return const [];
    final pinned = _pack(
      remaining: remaining,
      known: favorites,
      pinned: true,
    );
    var left = remaining - pinned.fold<int>(0, (sum, item) => sum + item.lineKcal);
    if (left < stopLeftover || pinned.length >= maxLines) return pinned;

    final extra = _pack(
      remaining: left,
      known: recent,
      pinned: false,
      skipNames: {
        for (final item in pinned) item.nameEn.trim().toLowerCase(),
      },
      usedLines: pinned.length,
    );
    return [...pinned, ...extra];
  }

  static List<RestSuggestion> _pack({
    required int remaining,
    required List<FavoriteMeal> known,
    required bool pinned,
    Set<String> skipNames = const {},
    int usedLines = 0,
  }) {
    final pool = <FavoriteMeal>[];
    final seen = {...skipNames};
    for (final fav in known) {
      if (!fav.canLogAgain || fav.kcal < minItemKcal) continue;
      final key = fav.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      pool.add(fav);
    }
    if (pool.isEmpty) return const [];

    if (pinned) {
      pool.sort((a, b) {
        final uses = b.useCount.compareTo(a.useCount);
        if (uses != 0) return uses;
        return b.kcal.compareTo(a.kcal);
      });
    } else {
      pool.sort((a, b) => b.kcal.compareTo(a.kcal));
    }

    final picked = <RestSuggestion>[];
    var left = remaining;
    var lines = usedLines;

    bool add(FavoriteMeal fav) {
      if (fav.kcal > left) return false;
      final index = picked.indexWhere((item) => item.favoriteId == fav.id);
      if (index >= 0) {
        if (picked[index].servings >= maxServings) return false;
        picked[index] = picked[index].withServings(picked[index].servings + 1);
      } else {
        if (lines >= maxLines) return false;
        lines += 1;
        picked.add(
          RestSuggestion(
            nameEn: fav.name,
            nameDe: fav.name,
            kcal: fav.kcal,
            fromFavorite: pinned,
            favoriteId: fav.id,
            proteinG: _proteinFor(fav),
          ),
        );
      }
      left -= fav.kcal;
      return true;
    }

    for (final fav in pool) {
      if (left < stopLeftover || lines >= maxLines) break;
      add(fav);
    }

    var grew = true;
    while (grew && left >= stopLeftover && lines <= maxLines) {
      grew = false;
      for (final fav in pool) {
        if (left < stopLeftover) break;
        if (add(fav)) grew = true;
      }
    }

    return picked;
  }

  static int _proteinFor(FavoriteMeal fav) {
    if (fav.proteinG > 0) return fav.proteinG.round();
    return ProteinMath.estimateGrams(name: fav.name, kcal: fav.kcal.toDouble()).round();
  }
}
