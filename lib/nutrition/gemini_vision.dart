import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:simple_calorie_tracker/nutrition/models.dart';

class GeminiVision {
  static const _models = [
    'gemini-3.7-flash',
    'gemini-3.6-flash',
  ];

  static const _prompt = '''
Identify every distinct food on this plate. Estimate the edible portion of each item in grams.

Rules:
- Do NOT estimate calories, macros, or nutrition. Grams and names only.
- queryEn must be a USDA FoodData Central style English search, cooked state included.
  Examples: "chicken breast grilled", "rice white cooked", "pasta cooked enriched", "olive oil".
- If a brand or packaged product is visible, put the brand in brandHint.
- Split mixed meals into visible components (protein, starch, sauce, sides).
- Ignore plates, cutlery, and non-food.
- mealName is a short human label for the whole meal.
- confidence is 0 to 1 for that item.
- altQueries: 2-3 broader USDA searches if the dish is restaurant-specific
  (e.g. greek pizza → "pizza feta", "cheese pizza").
''';

  static const _textPrompt = '''
Parse this meal description into foods. The user is naming what they are eating or want to eat.

Rules:
- Do NOT estimate calories, macros, or nutrition.
- If they wrote grams, kg, slices, or a portion, convert to grams and use that.
  A pizza slice is about 110g unless they say otherwise.
- If they omitted grams, estimate a typical served portion.
- Ignore restaurant names in queryEn. Map local dishes to a generic English food.
  Example: "greek pizza at nikos 350g" → name "Greek pizza", queryEn "greek pizza", grams 350,
  altQueries ["pizza feta olive", "cheese pizza"].
- brandHint only for a real packaged brand.
- Split "chicken 150g and rice 200g" into two items.
- mealName is a short label.
- confidence is 0 to 1.
''';

  static const _schema = {
    'type': 'OBJECT',
    'properties': {
      'mealName': {'type': 'STRING'},
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'queryEn': {'type': 'STRING'},
            'brandHint': {'type': 'STRING'},
            'grams': {'type': 'INTEGER'},
            'confidence': {'type': 'NUMBER'},
            'altQueries': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
          },
          'required': ['name', 'queryEn', 'grams'],
        },
      },
    },
    'required': ['mealName', 'items'],
  };

  Future<({String mealName, List<DetectedFood> items})> detectFoods({
    required Uint8List imageBytes,
    required String apiKey,
    int? knownGrams,
    String? note,
  }) async {
    return _detect(
      apiKey: apiKey,
      emptyMessage: 'No food was visible enough to estimate.',
      failMessage: 'Gemini could not read the photo.',
      parts: [
        {'text': '$_prompt${_knownGramsLine(knownGrams)}${_userNoteLine(note)}'},
        {
          'inline_data': {
            'mime_type': _mimeType(imageBytes),
            'data': base64Encode(imageBytes),
          },
        },
      ],
    );
  }

  Future<({String mealName, List<DetectedFood> items})> detectFromText({
    required String note,
    required String apiKey,
    int? knownGrams,
  }) async {
    return _detect(
      apiKey: apiKey,
      emptyMessage: 'Could not parse that description.',
      failMessage: 'Gemini could not read that description.',
      parts: [
        {'text': '$_textPrompt${_knownGramsLine(knownGrams)}\n\nUser text:\n$note'},
      ],
    );
  }

  String _knownGramsLine(int? knownGrams) {
    if (knownGrams == null || knownGrams <= 0) return '';
    return '\nThe user already knows the total edible weight is ${knownGrams}g '
        '(from a menu or a scale). Item grams MUST sum to $knownGrams. '
        'Do not pick a different total.';
  }

  String _userNoteLine(String? note) {
    final cleaned = note?.trim() ?? '';
    if (cleaned.isEmpty) return '';
    return '\nThe user already named the meal. Trust that over a visual guess '
        'when they conflict. Use the photo for portions, sides, and extras '
        'they did not mention.\nUser note:\n$cleaned';
  }

  Future<({String mealName, List<DetectedFood> items})> _detect({
    required String apiKey,
    required List<Map<String, Object>> parts,
    required String emptyMessage,
    required String failMessage,
  }) async {
    Object? lastError;
    for (final model in _models) {
      try {
        return await _detectWithModel(
          model: model,
          apiKey: apiKey,
          parts: parts,
          emptyMessage: emptyMessage,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError(failMessage);
  }

  Future<({String mealName, List<DetectedFood> items})> _detectWithModel({
    required String model,
    required String apiKey,
    required List<Map<String, Object>> parts,
    required String emptyMessage,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts},
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _schema,
          'thinkingConfig': {'thinkingLevel': 'LOW'},
        },
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError(_errorFromBody(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Gemini returned an unexpected response.');
    }
    final text = _extractText(decoded);
    final payload = _parseJsonObject(text);
    final rawItems = payload['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw StateError(emptyMessage);
    }

    final items = rawItems
        .whereType<Map>()
        .map((item) => DetectedFood.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty && item.grams > 0)
        .toList();
    if (items.isEmpty) {
      throw StateError(emptyMessage);
    }

    return (
      mealName: (payload['mealName'] ?? 'Meal').toString().trim(),
      items: items,
    );
  }

  String _extractText(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Gemini returned no candidates.');
    }
    final content = (candidates.first as Map)['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw StateError('Gemini returned an empty answer.');
    }
    final text = (parts.first as Map)['text']?.toString() ?? '';
    if (text.trim().isEmpty) {
      throw StateError('Gemini returned an empty answer.');
    }
    return text;
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    var raw = text.trim();
    if (raw.startsWith('```')) {
      raw = raw.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (raw.endsWith('```')) {
        raw = raw.substring(0, raw.length - 3).trim();
      }
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw StateError('Gemini did not return JSON.');
  }

  String _errorFromBody(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map ? error['message'] : null;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    if (statusCode == 400 || statusCode == 403) {
      return 'Gemini rejected the key or request.';
    }
    return 'Gemini request failed ($statusCode).';
  }

  String _mimeType(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
