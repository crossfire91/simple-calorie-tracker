import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenAccess.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/platform/database_setup.dart'
    if (dart.library.html) 'package:simple_calorie_tracker/platform/database_setup_web.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupDatabaseFactory();
  await initializeDateFormatting('de');
  await initializeDateFormatting('en');
  final localeController = await LocaleController.load();
  runApp(CalorieApp(localeController: localeController));
}

class CalorieApp extends StatelessWidget {
  final LocaleController localeController;

  const CalorieApp({super.key, required this.localeController});

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: localeController,
      child: AnimatedBuilder(
        animation: localeController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            locale: localeController.locale,
            supportedLocales: const [Locale('en'), Locale('de')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const CalorieSummaryScreenAccess(),
          );
        },
      ),
    );
  }
}
