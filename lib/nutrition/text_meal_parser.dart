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
  final g = RegExp(
    r'(?:^|[,\s])(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram|grams|gramm)\b',
    caseSensitive: false,
  ).firstMatch(text);
  final trailing = RegExp(r'(?:^|[,\s])(\d{2,4})\s*$').firstMatch(text);

  final match = g ?? kg ?? trailing;
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
  return DetectedFood(
    name: name,
    queryEn: name,
    grams: knownGrams ?? parsed.grams ?? 250,
    altQueries: _genericFallbacks(name),
  );
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
