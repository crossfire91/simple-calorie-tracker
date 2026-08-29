const mealTitleMaxChars = 42;

String summarizeMealTitle({
  required String note,
  String? modelTitle,
  List<String> itemNames = const [],
}) {
  final cleaned = _oneLine(note);
  final fromModel = _usableTitle(modelTitle, cleaned);
  if (fromModel != null) return fromModel;
  final fromItems = titleFromItems(itemNames);
  if (fromItems != null) return fromItems;
  return titleFromNote(cleaned);
}

String? originalMealNote({required String note, required String title}) {
  final cleaned = _oneLine(note);
  final short = title.trim();
  if (cleaned.isEmpty || short.isEmpty) return null;
  if (cleaned.toLowerCase() == short.toLowerCase()) return null;
  if (cleaned.length <= short.length + 6) return null;
  return cleaned;
}

String? titleFromItems(List<String> names) {
  final cleaned = [
    for (final name in names)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (cleaned.isEmpty) return null;
  if (cleaned.length == 1) return clipMealTitle(cleaned.first);
  final two = '${cleaned[0]} · ${cleaned[1]}';
  if (two.length <= mealTitleMaxChars) return two;
  return clipMealTitle(cleaned.first);
}

String titleFromNote(String note) {
  var text = _oneLine(note);
  if (text.isEmpty) return '';
  text = text.replaceAll(
    RegExp(
      r'\d+(?:[.,]\d+)?\s*(?:ml|l|g|kg|scoops?|messl[oö]ffel)\b',
      caseSensitive: false,
    ),
    ' ',
  );
  text = text.replaceAll(
    RegExp(r'\b(gemacht(?:\s+mit)?|und)\b|,', caseSensitive: false),
    ' ',
  );
  text = _oneLine(text);
  final words = text.split(' ').where((word) => word.isNotEmpty).take(6).join(' ');
  return clipMealTitle(words.isEmpty ? note : words);
}

String clipMealTitle(String raw) {
  final text = _oneLine(raw);
  if (text.length <= mealTitleMaxChars) return text;
  final cut = text.substring(0, mealTitleMaxChars);
  final space = cut.lastIndexOf(' ');
  return (space >= 16 ? cut.substring(0, space) : cut).trim();
}

String? _usableTitle(String? raw, String note) {
  final title = _oneLine(raw ?? '');
  if (title.isEmpty || title.length > 48) return null;
  if (note.length >= 50 && title.length > note.length - 12) return null;
  return title;
}

String _oneLine(String raw) => raw.replaceAll(RegExp(r'\s+'), ' ').trim();
