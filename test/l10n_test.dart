import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';

void main() {
  test('German and English UI copy stay distinct', () {
    const en = S(AppLang.en);
    const de = S(AppLang.de);

    expect(en.todayMeals, "TODAY'S MEALS");
    expect(de.todayMeals, 'HEUTIGE MAHLZEITEN');
    expect(en.newestFirst, 'Newest');
    expect(de.newestFirst, 'Neueste');
    expect(en.oldestFirst, 'Oldest');
    expect(de.oldestFirst, 'Älteste');
    expect(en.newestMealsFirst, 'Newest meals first');
    expect(de.newestMealsFirst, 'Neueste Mahlzeiten zuerst');
    expect(en.oldestMealsFirst, 'Oldest meals first');
    expect(de.oldestMealsFirst, 'Älteste Mahlzeiten zuerst');
    expect(en.mealGoalShare(21), '21% of the daily target');
    expect(de.mealGoalShare(21), '21% vom Tagesziel');
    expect(en.trendLabel(GoalType.lose, 0.5), 'Losing');
    expect(de.trendLabel(GoalType.lose, 0.5), 'Abnehmen');
    expect(de.trendLabel(GoalType.lose, 0), 'Abnehmen');
    expect(de.trendLabel(GoalType.maintain, 0), 'Halten');
    expect(en.weekLine(GoalType.lose, 0.48), contains('week'));
    expect(de.weekLine(GoalType.lose, 0.48), contains('Woche'));
    expect(de.weekLine(GoalType.lose, 0), 'Gewicht reduzieren');
    expect(de.weekLine(GoalType.maintain, 0), 'Dieses Gewicht halten');
    expect(de.lossTitle(LossHelper.scale), 'Küchenwaage');
    expect(de.prettyDate(DateTime(2026, 8, 29)), '29. August');
    expect(en.prettyDate(DateTime(2026, 8, 29)), 'August 29');
    final now = DateTime(2026, 8, 29);
    expect(de.relativeDay(now, now: now), 'Heute');
    expect(en.relativeDay(now, now: now), 'Today');
    expect(de.relativeDay(DateTime(2026, 8, 28), now: now), 'Gestern');
    expect(en.relativeDay(DateTime(2026, 8, 28), now: now), 'Yesterday');
    expect(de.relativeDay(DateTime(2026, 8, 27), now: now), 'Vorgestern');
    expect(en.relativeDay(DateTime(2026, 8, 27), now: now), 'The day before');
    expect(de.relativeDay(DateTime(2026, 8, 24), now: now), 'Vor 5 Tagen');
    expect(en.relativeDay(DateTime(2026, 8, 24), now: now), '5 days ago');
    expect(de.relativeDay(DateTime(2026, 8, 30), now: now), 'Morgen');
    expect(en.relativeDay(DateTime(2026, 8, 31), now: now), 'The day after');
    expect(de.relativeDay(DateTime(2026, 9, 2), now: now), 'In 4 Tagen');
    expect(en.updateNow, 'Update');
    expect(de.updateNow, 'Aktualisieren');
    expect(en.settings, 'Settings');
    expect(de.settings, 'Einstellungen');
    expect(en.language, 'Language');
    expect(de.language, 'Sprache');
    expect(en.apiKeys, 'API keys');
    expect(de.apiKeys, 'API-Schlüssel');
    expect(en.backupTitle, 'Backup');
    expect(de.backupTitle, 'Sicherung');
    expect(de.backupNow, 'Datei herunterladen');
    expect(de.backupToDrive, 'In Google Drive');
    expect(de.backupRestore, 'Von Datei');
    expect(de.backupRestoreFromDrive, 'Von Google Drive');
    expect(de.backupLastLine(DateTime(2026, 8, 29, 23, 40), 2400), contains('29. August'));
    expect(de.backupInventory(const BackupCounts(meals: 3, photos: 1, weights: 2)), contains('3 Mahlzeiten'));
    expect(de.updateAvailableSubtitle('1.2.0'), contains('1.2.0'));
    expect(en.orTypeIt, 'Or type it');
    expect(de.orTypeIt, 'Oder tippen');
    expect(en.exampleKcal, 'e.g. 2200');
    expect(de.exampleKcal, 'z. B. 2200');
    expect(en.kgPerWeekShort, 'kg/wk');
    expect(de.kgPerWeekShort, 'kg/Wo');
    expect(de.log, 'Eintragen');
    expect(de.editMeal, 'Mahlzeit bearbeiten');
    expect(de.originalNote, 'Originalbeschreibung');
    expect(de.buildMenu, 'Menü anlegen');
    expect(de.itemName, 'Name');
    expect(de.mealTitle, 'Titel');
    expect(de.saveChanges, 'Speichern');
    expect(de.looksFine, 'Übernehmen');
    expect(de.listening, contains('Aufnahme'));
    expect(en.looksFine, 'Looks correct');
    expect(de.scoopCountQuestion, contains('Scoops'));
    expect(
      de.lookupError('ClientException: Failed to fetch https://world.openfoodfacts.org/cgi/search.pl'),
      'Die Lebensmittelsuche war nicht erreichbar. Erneut versuchen oder die Energie selbst eintragen.',
    );
    expect(
      en.lookupError('ClientException: Failed to fetch https://world.openfoodfacts.org/cgi/search.pl'),
      'The food database was unreachable. Retry, or enter the energy manually.',
    );
  });

  test('system locale de becomes German', () {
    expect(LocaleController.fromSystem(const Locale('de', 'DE')), AppLang.de);
    expect(LocaleController.fromSystem(const Locale('en', 'US')), AppLang.en);
  });
}
