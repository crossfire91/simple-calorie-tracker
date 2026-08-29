import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:simple_calorie_tracker/nutrition/models.dart';

class OpenFoodFactsClient {
  static const _userAgent = 'SimpleCalorieTracker/1.0 (personal calorie tracker)';

  Future<NutritionLookupHit?> searchBest(String query) async {
    final hits = await search(query);
    if (hits.isEmpty) return null;
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.first;
  }

  Future<List<NutritionLookupHit>> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return const [];

    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': cleaned,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '8',
      'fields': 'product_name,brands,code,nutriments',
    });
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode >= 400) return const [];

    final decoded = jsonDecode(response.body);
    final products = decoded is Map ? decoded['products'] : null;
    if (products is! List) return const [];

    final hits = <NutritionLookupHit>[];
    for (final raw in products) {
      if (raw is! Map) continue;
      final product = Map<String, dynamic>.from(raw);
      final nutriments = product['nutriments'];
      if (nutriments is! Map) continue;
      final kcal = _kcalPer100g(Map<String, dynamic>.from(nutriments));
      if (kcal == null || kcal <= 0 || kcal > 950) continue;
      final name = [
        product['brands'],
        product['product_name'],
      ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
      if (name.isEmpty) continue;
      hits.add(
        NutritionLookupHit(
          name: name,
          kcalPer100g: kcal.round(),
          source: NutritionSource.openFoodFacts,
          id: product['code']?.toString(),
          score: _score(name, cleaned, nutriments),
        ),
      );
    }
    return hits;
  }

  double? _kcalPer100g(Map<String, dynamic> nutriments) {
    final direct = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal_value'];
    if (direct is num && direct > 0) return direct.toDouble();
    final parsed = double.tryParse(direct?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    final kj = nutriments['energy_100g'];
    if (kj is num && kj > 0) return kj / 4.184;
    return null;
  }

  int _score(String name, String query, Map nutriments) {
    final hay = name.toLowerCase();
    final needle = query.toLowerCase();
    var score = 8;
    if (hay.contains(needle)) score += 20;
    for (final word in needle.split(RegExp(r'\s+')).where((w) => w.length > 2)) {
      if (hay.contains(word)) score += 5;
    }
    if (nutriments.containsKey('proteins_100g')) score += 2;
    if (nutriments.containsKey('carbohydrates_100g')) score += 2;
    return score;
  }
}
