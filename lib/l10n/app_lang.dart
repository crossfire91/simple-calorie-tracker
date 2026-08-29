import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/platform/home_widget_sync.dart';

enum AppLang { en, de }

class LocaleController extends ChangeNotifier {
  AppLang lang;

  LocaleController([this.lang = AppLang.de]);

  Locale get locale => lang == AppLang.de ? const Locale('de') : const Locale('en');

  static AppLang fromSystem([Locale? locale]) {
    final code = (locale ?? WidgetsBinding.instance.platformDispatcher.locale).languageCode;
    return code == 'de' ? AppLang.de : AppLang.en;
  }

  static Future<LocaleController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('appLang');
    if (saved == 'en') return LocaleController(AppLang.en);
    return LocaleController(AppLang.de);
  }

  Future<void> setLang(AppLang next) async {
    if (lang == next) return;
    lang = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLang', next.name);
    await HomeWidgetSync.publishLanguage(next.name);
    notifyListeners();
  }

  Future<void> toggle() => setLang(lang == AppLang.de ? AppLang.en : AppLang.de);
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.notifier ?? LocaleController(AppLang.de);
  }
}
