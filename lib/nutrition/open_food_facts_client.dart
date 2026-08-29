import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:simple_calorie_tracker/nutrition/food_sense.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';

class OpenFoodFactsClient {
  OpenFoodFactsClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _timeout = Duration(seconds: 10);
  static const _appId = 'SimpleCalorieTracker/1.0';
  static const _fields = 'code,product_name,brands,nutriments';

  Future<NutritionLookupHit?> searchBest(String query, {FoodSense? sense}) async {
    final hits = await search(query);
    if (sense != null) return pickVerifiedHit(hits, sense);
    if (hits.isEmpty) return null;
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.first;
  }

  Future<List<NutritionLookupHit>> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return const [];

    // Search-a-licious has no usable CORS headers for Flutter web.
    if (!kIsWeb) {
      try {
        final modern = await _searchModern(cleaned);
        if (modern.isNotEmpty) return modern;
      } catch (_) {}
    }

    try {
      return await _searchLegacy(cleaned);
    } catch (_) {
      return const [];
    }
  }

  Future<List<NutritionLookupHit>> _searchModern(String query) async {
    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': query,
      'page_size': '8',
      'fields': _fields,
      'langs': 'de,en',
    });
    final response = await _http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode >= 400) return const [];
    return hitsFromResponse(jsonDecode(response.body), query);
  }

  Future<List<NutritionLookupHit>> _searchLegacy(String query) async {
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '8',
      'fields': 'product_name,brands,code,nutriments',
    });
    final response = await _http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode >= 400) return const [];
    return hitsFromResponse(jsonDecode(response.body), query);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-User-Agent': _appId,
    };
    // Custom User-Agent is a forbidden browser header and OFF often answers
    // 503 without CORS, which Flutter web surfaces as "Failed to fetch".
    if (!kIsWeb) {
      headers['User-Agent'] = 'Mozilla/5.0 (compatible; $_appId)';
    }
    return headers;
  }

  @visibleForTesting
  static List<NutritionLookupHit> hitsFromResponse(Object? decoded, String query) {
    if (decoded is! Map) return const [];
    final products = decoded['hits'] ?? decoded['products'];
    if (products is! List) return const [];

    final hits = <NutritionLookupHit>[];
    for (final raw in products) {
      if (raw is! Map) continue;
      final product = Map<String, dynamic>.from(raw);
      final nutriments = product['nutriments'];
      if (nutriments is! Map) continue;
      final kcal = _kcalPer100g(Map<String, dynamic>.from(nutriments));
      if (kcal == null || kcal < 0 || kcal > 950) continue;
      final name = [
        _brandLabel(product['brands']),
        product['product_name']?.toString(),
      ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
      if (name.isEmpty) continue;
      hits.add(
        NutritionLookupHit(
          name: name,
          kcalPer100g: kcal.round(),
          source: NutritionSource.openFoodFacts,
          id: product['code']?.toString(),
          score: _score(name, query, nutriments),
        ),
      );
    }
    return hits;
  }

  static String? _brandLabel(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is List) {
      final parts = raw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty);
      if (parts.isEmpty) return null;
      return parts.join(', ');
    }
    return null;
  }

  static double? _kcalPer100g(Map<String, dynamic> nutriments) {
    final direct = nutriments['energy-kcal_100g'];
    if (direct is num && direct >= 0) return direct.toDouble();
    final parsed = double.tryParse(direct?.toString() ?? '');
    if (parsed != null && parsed >= 0) return parsed;
    final kj = nutriments['energy_100g'] ?? nutriments['energy-kj_100g'];
    if (kj is num && kj > 0) return kj / 4.184;
    return null;
  }

  static int _score(String name, String query, Map nutriments) {
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
