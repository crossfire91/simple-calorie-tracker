import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';
import 'package:simple_calorie_tracker/widgets/settings_menu.dart';

Widget _wrap(Widget child, {required LocaleController controller}) {
  return LocaleScope(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('burger menu opens language, backup, keys and version', (tester) async {
    var backup = false;
    var keys = false;
    var update = false;
    final controller = LocaleController(AppLang.de);

    await tester.pumpWidget(
      _wrap(
        SettingsMenuButton(
          onBackup: () => backup = true,
          onApiKeys: () => keys = true,
          onCheckUpdate: () => update = true,
        ),
        controller: controller,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Sicherung'), findsOneWidget);
    expect(find.text('API-Schlüssel'), findsOneWidget);
    expect(find.text('DE → EN'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('Nach Update suchen'), findsOneWidget);

    await tester.tap(find.text('Sicherung'));
    await tester.pumpAndSettle();
    expect(backup, isTrue);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('API-Schlüssel'));
    await tester.pumpAndSettle();
    expect(keys, isTrue);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    expect(controller.lang, AppLang.en);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('v1.1.0'));
    await tester.pumpAndSettle();
    expect(update, isTrue);
  });

  testWidgets('version row names a ready update', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SettingsMenuButton(
          onBackup: () {},
          onApiKeys: () {},
          onCheckUpdate: () {},
          updateStatus: const UpdateStatus(
            installed: InstalledVersion(versionName: '1.1.0', versionCode: 2),
            newer: UpdateRelease(
              versionName: '1.2.0',
              versionCode: 3,
              apkUrl: 'https://example.com/app.apk',
            ),
            checked: true,
          ),
        ),
        controller: LocaleController(AppLang.de),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('v1.1.0 · Update 1.2.0'), findsOneWidget);
  });
}
