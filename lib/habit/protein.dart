class ProteinMath {
  static final _split = RegExp(r'[^a-zäöüß]+');

  static double estimateGrams({
    required String name,
    required double kcal,
  }) {
    if (kcal <= 0) return 0;
    final n = name.toLowerCase();
    var fraction = 0.16;
    if (_hits(n, const [
      'chicken',
      'hähnchen',
      'haehnchen',
      'turkey',
      'pute',
      'tofu',
      'egg',
      'eggs',
      'ei',
      'eier',
      'yogurt',
      'joghurt',
      'quark',
      'cottage',
      'hüttenkäse',
      'huettenkaese',
      'fish',
      'lachs',
      'salmon',
      'tuna',
      'thunfisch',
      'protein',
      'whey',
      'steak',
      'rind',
      'beef',
    ])) {
      fraction = 0.32;
    } else if (_hits(n, const [
      'pizza',
      'pasta',
      'nudel',
      'cake',
      'kuchen',
      'cookie',
      'schoko',
      'chocolate',
      'chips',
      'fries',
      'pommes',
      'ice cream',
      'eis',
      'soda',
      'cola',
    ])) {
      fraction = 0.08;
    }
    return (kcal * fraction) / 4.0;
  }

  static int dailyTargetGrams(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return 90;
    return (weightKg * 1.6).round().clamp(70, 180);
  }

  /// Short needles must be whole words so "Reis" is not "Ei".
  static bool _hits(String name, List<String> needles) {
    final tokens = name.split(_split).where((part) => part.isNotEmpty).toSet();
    for (final needle in needles) {
      if (needle.length <= 3) {
        if (tokens.contains(needle)) return true;
      } else if (name.contains(needle)) {
        return true;
      }
    }
    return false;
  }
}
