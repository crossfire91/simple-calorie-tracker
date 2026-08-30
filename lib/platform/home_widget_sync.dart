import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeWidgetAction {
  final String name;
  final String? favoriteId;

  const HomeWidgetAction(this.name, {this.favoriteId});

  bool get isAdd => name == 'add';
  bool get isFavorite => name == 'favorite' && (favoriteId?.isNotEmpty ?? false);
}

class HomeWidgetSync {
  static const _channel = MethodChannel('simple_calorie_tracker/home_widget');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static HomeWidgetAction? parseAction(dynamic raw) {
    if (raw is! Map) return null;
    final name = raw['action']?.toString();
    if (name == null || name.isEmpty) return null;
    final favoriteId = raw['favoriteId']?.toString();
    return HomeWidgetAction(
      name,
      favoriteId: (favoriteId == null || favoriteId.isEmpty) ? null : favoriteId,
    );
  }

  static List<Map<String, Object>> mealLines(
    Iterable<dynamic> items, {
    int limit = 8,
  }) {
    return [
      for (final item in items.take(limit))
        if (item is Map)
          {
            'name': (item['name'] as String? ?? '').trim(),
            'kcal': _lineKcal(item),
            'time': _lineTime(item['loggedAt']),
          },
    ];
  }

  static int _lineKcal(Map item) {
    final grams = (item['weightInGrams'] as num?) ?? 0;
    final per100 = (item['kcalPer100g'] as num?) ?? 0;
    return (grams * per100 / 100).round();
  }

  static String _lineTime(dynamic stamp) {
    if (stamp is! num || stamp <= 0) return '';
    final time = DateTime.fromMillisecondsSinceEpoch(stamp.toInt());
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static Future<void> publish({
    required int consumedKcal,
    required int budgetKcal,
    required String dateKey,
    required String lang,
    int mealCount = 0,
    List<Map<String, Object>> favorites = const [],
    List<Map<String, Object>> meals = const [],
    String coachLineDe = '',
    String coachLineEn = '',
    String coachMood = 'nextPlate',
    int proteinGrams = 0,
    int proteinTarget = 90,
    String proteinName = '',
    String proteinFavoriteId = '',
    int streak = 0,
  }) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod('update', {
        'consumedKcal': consumedKcal,
        'budgetKcal': budgetKcal,
        'dateKey': dateKey,
        'lang': lang,
        'mealCount': mealCount,
        'favorites': favorites,
        'meals': meals,
        'coachLineDe': coachLineDe,
        'coachLineEn': coachLineEn,
        'coachMood': coachMood,
        'proteinGrams': proteinGrams,
        'proteinTarget': proteinTarget,
        'proteinName': proteinName,
        'proteinFavoriteId': proteinFavoriteId,
        'streak': streak,
      });
    } catch (_) {}
  }

  static Future<void> publishLanguage(String lang) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod('updateLang', {'lang': lang});
    } catch (_) {}
  }

  static Future<void> stop() async {
    _channel.setMethodCallHandler(null);
  }

  static Future<void> listen(void Function(HomeWidgetAction action) onAction) async {
    if (!_android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onWidgetAction') return;
      final action = parseAction(call.arguments);
      if (action != null) onAction(action);
    });
    try {
      final pending = parseAction(await _channel.invokeMethod('takeLaunchAction'));
      if (pending != null) onAction(pending);
    } catch (_) {}
  }
}
