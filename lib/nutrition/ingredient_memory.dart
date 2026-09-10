import 'package:simple_calorie_tracker/nutrition/models.dart';

class LoggedPlate {
  final String name;
  final int kcalPer100g;
  final String breakdown;
  final int loggedAt;

  const LoggedPlate({
    required this.name,
    required this.kcalPer100g,
    this.breakdown = '',
    this.loggedAt = 0,
  });
}

class IngredientMemory {
  final Map<String, int> _kcalPer100g;

  const IngredientMemory(this._kcalPer100g);

  factory IngredientMemory.empty() => const IngredientMemory({});

  /// Newest plates first. The first density for a name wins.
  factory IngredientMemory.fromMeals(Iterable<LoggedPlate> meals) {
    final kcalPer100g = <String, int>{};
    for (final meal in meals) {
      final estimate = MealEstimate.tryDecode(meal.breakdown);
      if (estimate != null && estimate.items.isNotEmpty) {
        for (final item in estimate.items) {
          _offer(kcalPer100g, item.detected.name, item.kcalPer100g);
        }
        continue;
      }
      _offer(kcalPer100g, meal.name, meal.kcalPer100g);
    }
    return IngredientMemory(kcalPer100g);
  }

  bool get isEmpty => _kcalPer100g.isEmpty;

  static String keyOf(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  int? lookup(String name) {
    final key = keyOf(name);
    if (key.length < 2) return null;
    return _kcalPer100g[key];
  }

  static void _offer(Map<String, int> into, String name, int kcalPer100g) {
    final key = keyOf(name);
    if (key.length < 2 || kcalPer100g <= 0) return;
    into.putIfAbsent(key, () => kcalPer100g.clamp(1, 950));
  }
}
