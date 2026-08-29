import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';
import 'package:simple_calorie_tracker/widgets/update_banner.dart';
import 'package:simple_calorie_tracker/widgets/version_footer.dart';

void main() {
  const installed = InstalledVersion(versionName: '1.1.0', versionCode: 2);

  test('manifest with higher versionCode is an update', () {
    final release = parseManifest('''
      {
        "versionName": "1.2.0",
        "versionCode": 3,
        "apkUrl": "https://example.com/app.apk",
        "notes": "Protein widget"
      }
    ''');
    expect(release?.versionName, '1.2.0');
    expect(release?.isNewerThan(installed), isTrue);
  });

  test('same or empty apk is not an update', () {
    expect(
      parseManifest('''
        {"versionName":"1.2.0","versionCode":3,"apkUrl":""}
      ''')?.isNewerThan(installed),
      isFalse,
    );
    expect(
      parseManifest('''
        {"versionName":"1.1.0","versionCode":2,"apkUrl":"https://example.com/app.apk"}
      ''')?.isNewerThan(installed),
      isFalse,
    );
  });

  test('github release uses apk asset and versionCode in body', () {
    final release = parseGithubRelease('''
      {
        "tag_name": "v1.3.0",
        "body": "versionCode: 4\\nWidgets stay in sync.",
        "assets": [
          {
            "name": "app-release.apk",
            "browser_download_url": "https://github.com/matha/simple-calorie-tracker/releases/download/v1.3.0/app-release.apk"
          }
        ]
      }
    ''');
    expect(release?.versionName, '1.3.0');
    expect(release?.versionCode, 4);
    expect(release?.hasApk, isTrue);
    expect(release?.isNewerThan(installed), isTrue);
  });

  test('semver compare treats plus-build as newer', () {
    expect(compareSemver('v1.2.0', '1.1.9'), greaterThan(0));
    expect(compareSemver('1.1.0+3', '1.1.0+2'), greaterThan(0));
    expect(compareSemver('1.1.0', '1.1.0+2'), lessThan(0));
  });

  test('newer version without apk still counts as not current', () {
    final release = parseManifest('''
      {"versionName":"1.2.0","versionCode":3,"apkUrl":""}
    ''');
    expect(release?.isNewerVersionThan(installed), isTrue);
    expect(release?.isNewerThan(installed), isFalse);
  });

  testWidgets('update banner names the version and the one-tap action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.de),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: UpdateBanner(
              release: const UpdateRelease(
                versionName: '1.2.0',
                versionCode: 3,
                apkUrl: 'https://example.com/app.apk',
              ),
              onUpdate: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Update bereit'), findsOneWidget);
    expect(find.textContaining('1.2.0'), findsOneWidget);
    await tester.tap(find.text('Aktualisieren'));
    expect(tapped, isTrue);
  });

  testWidgets('version footer shows current or update status', (tester) async {
    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.de),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: VersionFooter(
              status: UpdateStatus(
                installed: InstalledVersion(versionName: '1.1.0', versionCode: 2),
                checked: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('v1.1.0 · aktuell'), findsOneWidget);

    await tester.pumpWidget(
      LocaleScope(
        controller: LocaleController(AppLang.de),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: VersionFooter(
              status: UpdateStatus(
                installed: const InstalledVersion(versionName: '1.1.0', versionCode: 2),
                newer: const UpdateRelease(
                  versionName: '1.2.0',
                  versionCode: 3,
                  apkUrl: 'https://example.com/app.apk',
                ),
                checked: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('v1.1.0 · Update 1.2.0'), findsOneWidget);
  });
}
