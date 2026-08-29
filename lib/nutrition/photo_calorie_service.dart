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
    String? extraContext,
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
      extraContext: extraContext,
    );
    return _grounded(
      detected.mealName,
      detected.items,
      geminiKey,
      knownGrams,
      detected.clarification,
    );
  }

  Future<MealEstimate> estimateFromNote(
    String note, {
    int? knownGrams,
    String? extraContext,
  }) async {
    final cleaned = note.trim();
    if (cleaned.isEmpty) {
      throw StateError('Write what it actually is. Grams are optional.');
    }

    final geminiKey = await NutritionApiKeys.gemini();
    late final String mealName;
    late final List<DetectedFood> items;
    ClarificationQuestion? clarification;
    if (geminiKey.isNotEmpty) {
      final detected = await _vision.detectFromText(
        note: cleaned,
        apiKey: geminiKey,
        knownGrams: knownGrams,
        extraContext: extraContext,
      );
      mealName = detected.mealName;
      items = detected.items;
      clarification = detected.clarification;
    } else {
      items = splitMealNote(cleaned, knownGrams: knownGrams);
      mealName = items.length == 1 ? items.first.name : cleaned;
    }

    return _grounded(
      mealName,
      items,
      geminiKey.isEmpty ? null : geminiKey,
      knownGrams,
      extraContext == null || extraContext.trim().isEmpty ? clarification : null,
    );
  }

  Future<({MealEstimate estimate, String transcript})> estimateFromAudio(
    Uint8List audioBytes, {
    required String mimeType,
    int? knownGrams,
    String? extraContext,
  }) async {
    if (audioBytes.isEmpty) {
      throw StateError('Could not hear a meal in that recording.');
    }
    final geminiKey = await NutritionApiKeys.gemini();
    if (geminiKey.isEmpty) {
      throw StateError(
        'Add a Gemini API key in settings. Calories still come from USDA / Open Food Facts.',
      );
    }
    final detected = await _vision.detectFromAudio(
      audioBytes: audioBytes,
      mimeType: mimeType,
      apiKey: geminiKey,
      knownGrams: knownGrams,
      extraContext: extraContext,
    );
    return (
      estimate: await _grounded(
        detected.mealName,
        detected.items,
        geminiKey,
        knownGrams,
        extraContext == null || extraContext.trim().isEmpty ? detected.clarification : null,
      ),
      transcript: detected.transcript.isNotEmpty ? detected.transcript : detected.mealName,
    );
  }

  Future<MealEstimate> _grounded(
    String mealName,
    List<DetectedFood> items,
    String? geminiKey,
    int? knownGrams,
    ClarificationQuestion? clarification,
  ) async {
    var estimate = await _lookup.ground(
      mealName: mealName,
      items: items,
      usdaKey: await NutritionApiKeys.usda(),
      geminiKey: geminiKey,
    );
    if (knownGrams != null && knownGrams > 0) {
      estimate = estimate.withKnownGrams(knownGrams);
    }
    return estimate.copyWith(clarification: clarification);
  }

  Future<MealEstimate> groundItems({
    required String mealName,
    required List<DetectedFood> items,
    int? knownGrams,
  }) async {
    final geminiKey = await NutritionApiKeys.gemini();
    return _grounded(
      mealName,
      items,
      geminiKey.isEmpty ? null : geminiKey,
      knownGrams,
      null,
    );
  }
}
