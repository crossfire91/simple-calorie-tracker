import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:simple_calorie_tracker/nutrition/models.dart';

class WebNutritionHint {
  final String name;
  final String? genericQuery;
  final int? kcalPer100g;
  final String? sourceTitle;
  final String? sourceUrl;

  const WebNutritionHint({
    required this.name,
    this.genericQuery,
    this.kcalPer100g,
    this.sourceTitle,
    this.sourceUrl,
  });
}

/// Last-resort lookup: Gemini + Google Search, only after USDA / OFF miss.
class WebGrounding {
  static const _models = [
    'gemini-3.7-flash',
    'gemini-3.6-flash',
  ];

  static const _schema = {
    'type': 'OBJECT',
    'properties': {
      'results': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'genericQuery': {'type': 'STRING'},
            'kcalPer100g': {'type': 'INTEGER'},
            'sourceTitle': {'type': 'STRING'},
            'sourceUrl': {'type': 'STRING'},
            'found': {'type': 'BOOLEAN'},
          },
          'required': ['name', 'found'],
        },
      },
    },
    'required': ['results'],
  };

  Future<Map<String, WebNutritionHint>> lookup({
    required List<DetectedFood> items,
    required String apiKey,
  }) async {
    if (items.isEmpty) return const {};

    final catalog = items
        .map((item) => '- ${item.name} (search as: ${item.queryEn.isEmpty ? item.name : item.queryEn})')
        .join('\n');
    final prompt = '''
These foods were not found in USDA FoodData Central or Open Food Facts.

$catalog

Use Google Search. For each item:
1. Prefer an official restaurant nutrition PDF, government table, or major chain facts.
2. genericQuery: a short USDA-style English name we can search again (no restaurant name).
3. kcalPer100g: only if a source states energy. Convert per-serving to per 100g when grams are given.
4. sourceTitle and sourceUrl of that page.
5. found=false if you cannot cite a number. Do not invent calories.
''';

    Object? lastError;
    for (final model in _models) {
      try {
        return await _request(model: model, apiKey: apiKey, prompt: prompt);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Web search could not ground those foods.');
  }

  Future<Map<String, WebNutritionHint>> _request({
    required String model,
    required String apiKey,
    required String prompt,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'tools': [
          {'googleSearch': {}},
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _schema,
          'thinkingConfig': {'thinkingLevel': 'LOW'},
        },
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('Web search failed (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Web search returned an unexpected response.');
    }
    final text = _extractText(decoded);
    final payload = _parseJsonObject(text);
    final raw = payload['results'];
    if (raw is! List) return const {};

    final hints = <String, WebNutritionHint>{};
    for (final row in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final name = (map['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final found = map['found'] == true;
      final kcal = _asInt(map['kcalPer100g']);
      hints[name.toLowerCase()] = WebNutritionHint(
        name: name,
        genericQuery: (map['genericQuery'] ?? '').toString().trim().isEmpty
            ? null
            : map['genericQuery'].toString().trim(),
        kcalPer100g: found ? kcal : null,
        sourceTitle: (map['sourceTitle'] ?? '').toString().trim().isEmpty
            ? null
            : map['sourceTitle'].toString().trim(),
        sourceUrl: (map['sourceUrl'] ?? '').toString().trim().isEmpty
            ? null
            : map['sourceUrl'].toString().trim(),
      );
    }
    return hints;
  }

  String _extractText(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Web search returned no candidates.');
    }
    final content = (candidates.first as Map)['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw StateError('Web search returned an empty answer.');
    }
    final text = (parts.first as Map)['text']?.toString() ?? '';
    if (text.trim().isEmpty) {
      throw StateError('Web search returned an empty answer.');
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
    throw StateError('Web search did not return JSON.');
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
