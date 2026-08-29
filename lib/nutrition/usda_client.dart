import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:simple_calorie_tracker/nutrition/food_sense.dart';
import 'package:simple_calorie_tracker/nutrition/known_foods.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';

class UsdaClient {
  static const _dataTypes = ['Foundation', 'SR Legacy', 'Survey (FNDDS)', 'Branded'];

  Future<NutritionLookupHit?> searchBest(String query, String apiKey, {FoodSense? sense}) async {
    final hits = await search(query, apiKey);
    if (sense != null) return pickVerifiedHit(hits, sense);
    if (hits.isEmpty) return null;
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.first;
  }

  Future<List<NutritionLookupHit>> search(String query, String apiKey) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return const [];

    final uri = Uri.parse(
      'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${Uri.encodeQueryComponent(apiKey)}',
    );
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': cleaned,
              'pageSize': 8,
              'dataType': _dataTypes,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return const [];
    }
    if (response.statusCode >= 400) return const [];

    final decoded = jsonDecode(response.body);
    final foods = decoded is Map ? decoded['foods'] : null;
    if (foods is! List) return const [];

    final hits = <NutritionLookupHit>[];
    for (final raw in foods) {
      if (raw is! Map) continue;
      final food = Map<String, dynamic>.from(raw);
      final kcal = _energyKcal(food);
      if (kcal == null || kcal < 0 || kcal > 950) continue;
      if (isPlantMilkQuery(cleaned) && kcal > 65) continue;
      final name = (food['description'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      hits.add(
        NutritionLookupHit(
          name: name,
          kcalPer100g: kcal.round(),
          source: NutritionSource.usda,
          id: food['fdcId']?.toString(),
          score: scoreFor(name, food['dataType']?.toString() ?? '', cleaned),
        ),
      );
    }
    return hits;
  }

  double? _energyKcal(Map<String, dynamic> food) {
    final label = food['labelNutrients'];
    if (label is Map) {
      final calories = label['calories'];
      final value = calories is Map ? calories['value'] : null;
      if (value is num && value >= 0) {
        final serving = food['servingSize'];
        final unit = (food['servingSizeUnit'] ?? '').toString().toLowerCase();
        if (serving is num && serving > 0 && (unit == 'g' || unit == 'gr' || unit == 'gram')) {
          return value * 100 / serving;
        }
      }
    }

    final nutrients = food['foodNutrients'];
    if (nutrients is! List) return null;
    double? kcal;
    double? kj;
    for (final raw in nutrients) {
      if (raw is! Map) continue;
      final nutrient = Map<String, dynamic>.from(raw);
      final unit = (nutrient['unitName'] ?? '').toString().toUpperCase();
      final number = (nutrient['nutrientNumber'] ?? '').toString();
      final id = nutrient['nutrientId'];
      final value = nutrient['value'];
      if (value is! num) continue;
      final isEnergy = number == '208' || id == 1008 ||
          (nutrient['nutrientName']?.toString().toLowerCase() == 'energy' && unit == 'KCAL');
      final isKj = number == '268' || id == 1062 || unit == 'KJ';
      if (isEnergy && unit != 'KJ') kcal = value.toDouble();
      if (isKj) kj = value.toDouble();
    }
    if (kcal != null) return kcal;
    if (kj != null) return kj / 4.184;
    return null;
  }

  @visibleForTesting
  static int scoreFor(String name, String dataType, String query) {
    final hay = name.toLowerCase();
    final needle = query.toLowerCase();
    var score = 0;
    if (hay == needle) score += 50;
    if (hay.contains(needle)) score += 18;
    for (final word in needle.split(RegExp(r'\s+')).where((w) => w.length > 2)) {
      if (hay.contains(word)) score += 4;
    }
    if (isWaterQuery(needle)) {
      if (isPlainWaterName(hay)) score += 40;
      if (isFlavoredWaterName(hay)) score -= 50;
    }
    if (isPlantMilkQuery(needle)) {
      if (!hay.contains('milk') && !hay.contains('beverage') && !hay.contains('drink')) {
        score -= 40;
      }
      if (hay.contains('butter') || hay.contains('flour') || hay.contains('roasted') || hay.contains('nuts')) {
        score -= 40;
      }
      if (!mentionsSweetenedOnly(needle) && hay.contains('unsweetened')) score += 22;
      if (!mentionsSweetenedOnly(needle) &&
          (hay.contains('sweetened') || hay.contains('vanilla') || hay.contains('chocolate'))) {
        score -= 18;
      }
    }
    switch (dataType) {
      case 'Foundation':
        score += 30;
        break;
      case 'SR Legacy':
        score += 24;
        break;
      case 'Survey (FNDDS)':
        score += 16;
        break;
      case 'Branded':
        score += 6;
        break;
    }
    return score;
  }
}
