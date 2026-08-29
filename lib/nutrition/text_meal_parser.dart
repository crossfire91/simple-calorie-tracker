import 'package:simple_calorie_tracker/nutrition/food_sense.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';

class ParsedMealNote {
  final String name;
  final int? grams;

  const ParsedMealNote({required this.name, this.grams});
}

/// Pulls an optional portion out of free text when Gemini is unavailable.
ParsedMealNote parseMealNote(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return const ParsedMealNote(name: '');

  int? grams;
  final kg = RegExp(r'(?:^|[,\s])(\d+(?:[.,]\d+)?)\s*kg\b', caseSensitive: false).firstMatch(text);
  final ml = RegExp(r'(?:^|[,\s])(\d+(?:[.,]\d+)?)\s*ml\b', caseSensitive: false).firstMatch(text);
  final g = RegExp(
    r'(?:^|[,\s])(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram|grams|gramm)\b',
    caseSensitive: false,
  ).firstMatch(text);
  final trailing = RegExp(r'(?:^|[,\s])(\d{2,4})\s*$').firstMatch(text);

  final match = g ?? ml ?? kg ?? trailing;
  if (match != null) {
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value != null && value > 0) {
      grams = kg != null ? (value * 1000).round() : value.round();
      text = (text.substring(0, match.start) + text.substring(match.end)).trim();
    }
  }

  text = text.replaceAll(RegExp(r'^[\s,.\-/]+|[\s,.\-/]+$'), '');
  return ParsedMealNote(name: text, grams: grams);
}

DetectedFood detectedFromNote(String raw, {int? knownGrams}) {
  final parsed = parseMealNote(raw);
  final name = parsed.name.isEmpty ? raw.trim() : parsed.name;
  final food = DetectedFood(
    name: name,
    queryEn: name,
    grams: knownGrams ?? parsed.grams ?? _scoopGrams(raw) ?? 250,
    altQueries: _genericFallbacks(name),
  );
  return food.copyWith(sense: inferFoodSense(food));
}

/// Split a typed note into menu rows when Gemini is not used.
List<DetectedFood> splitMealNote(String raw, {int? knownGrams}) {
  var text = raw.trim();
  if (text.isEmpty) return const [];
  text = text.replaceAll(RegExp(r'\bgemacht\s+mit\b', caseSensitive: false), 'mit');
  final parts = text
      .split(
        RegExp(
          r'\s*(?:,|;|\bund\b|\band\b|\s+mit\s+(?=[^,]{0,40}\d+\s*(?:ml|g|scoops?)))\s*',
          caseSensitive: false,
        ),
      )
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length <= 1) {
    return [detectedFromNote(text, knownGrams: knownGrams)];
  }
  return [
    for (final part in parts) detectedFromNote(part),
  ];
}

int? _scoopGrams(String raw) {
  if (RegExp(r'\b(doppelt\w*|double|zwei|2)\b.*\b(scoops?|messl)', caseSensitive: false).hasMatch(raw) ||
      RegExp(r'\b(scoops?|messl).*\b(doppelt\w*|double|zwei|2)\b', caseSensitive: false).hasMatch(raw)) {
    return 60;
  }
  if (RegExp(r'\b(scoops?|messl[oö]ffel)\b', caseSensitive: false).hasMatch(raw)) return 30;
  return null;
}

List<String> _genericFallbacks(String name) {
  final cleaned = name
      .replaceAll(
        RegExp(
          r'\b(at|from|bei|im|in|restaurant|pizzeria|taverna|grill|bar)\b.*',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (cleaned.isEmpty || cleaned.toLowerCase() == name.toLowerCase()) {
    return const [];
  }
  return [cleaned];
}
