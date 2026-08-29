import 'dart:typed_data';

import 'package:simple_calorie_tracker/nutrition/api_keys.dart';
import 'package:simple_calorie_tracker/nutrition/gemini_vision.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/nutrition_lookup.dart';
import 'package:simple_calorie_tracker/nutrition/text_meal_parser.dart';

class PhotoCalorieService {
  PhotoCalorieService({
    GeminiVision? vision,
    NutritionLookup? lookup,
  })  : _vision = vision ?? GeminiVision(),
        _lookup = lookup ?? NutritionLookup();

  final GeminiVision _vision;
  final NutritionLookup _lookup;

  Future<MealEstimate> estimateFromPhoto(
    Uint8List imageBytes, {
    int? knownGrams,
    String? note,
  }) async {
    final geminiKey = await NutritionApiKeys.gemini();
    if (geminiKey.isEmpty) {
      throw StateError(
        'Add a Gemini API key in settings. Calories still come from USDA / Open Food Facts.',
      );
    }
    final detected = await _vision.detectFoods(
      imageBytes: imageBytes,
      apiKey: geminiKey,
      knownGrams: knownGrams,
      note: note,
    );
    return _grounded(detected.mealName, detected.items, geminiKey, knownGrams);
  }

  Future<MealEstimate> estimateFromNote(String note, {int? knownGrams}) async {
    final cleaned = note.trim();
    if (cleaned.isEmpty) {
      throw StateError('Write what it actually is. Grams are optional.');
    }

    final geminiKey = await NutritionApiKeys.gemini();
    late final String mealName;
    late final List<DetectedFood> items;
    if (geminiKey.isNotEmpty) {
      final detected = await _vision.detectFromText(
        note: cleaned,
        apiKey: geminiKey,
        knownGrams: knownGrams,
      );
      mealName = detected.mealName;
      items = detected.items;
    } else {
      final fallback = detectedFromNote(cleaned, knownGrams: knownGrams);
      mealName = fallback.name;
      items = [fallback];
    }

    return _grounded(mealName, items, geminiKey.isEmpty ? null : geminiKey, knownGrams);
  }

  Future<MealEstimate> _grounded(
    String mealName,
    List<DetectedFood> items,
    String? geminiKey,
    int? knownGrams,
  ) async {
    final estimate = await _lookup.ground(
      mealName: mealName,
      items: items,
      usdaKey: await NutritionApiKeys.usda(),
      geminiKey: geminiKey,
    );
    if (knownGrams == null || knownGrams <= 0) return estimate;
    return estimate.withKnownGrams(knownGrams);
  }
}
