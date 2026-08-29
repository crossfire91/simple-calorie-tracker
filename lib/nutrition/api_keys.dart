import 'package:shared_preferences/shared_preferences.dart';

class NutritionApiKeys {
  static const geminiPref = 'geminiApiKey';
  static const usdaPref = 'usdaApiKey';

  static Future<String> gemini() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(geminiPref)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    return const String.fromEnvironment('GEMINI_API_KEY').trim();
  }

  static Future<String> usda() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(usdaPref)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final fromEnv = const String.fromEnvironment('USDA_API_KEY').trim();
    return fromEnv.isEmpty ? 'DEMO_KEY' : fromEnv;
  }

  static Future<void> save({required String geminiKey, required String usdaKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(geminiPref, geminiKey.trim());
    await prefs.setString(usdaPref, usdaKey.trim());
  }

  static Future<bool> hasGemini() async => (await gemini()).isNotEmpty;
}
