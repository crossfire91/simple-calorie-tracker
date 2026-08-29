import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';

void main() {
  test('German and English UI copy stay distinct', () {
    const en = S(AppLang.en);
    const de = S(AppLang.de);

    expect(en.todayMeals, "TODAY'S MEALS");
    expect(de.todayMeals, 'HEUTIGE MAHLZEITEN');
    expect(en.trendLabel(GoalType.lose, 0.5), 'Losing');
    expect(de.trendLabel(GoalType.lose, 0.5), 'Abnehmen');
    expect(en.weekLine(GoalType.lose, 0.48), contains('week'));
    expect(de.weekLine(GoalType.lose, 0.48), contains('Woche'));
    expect(de.lossTitle(LossHelper.scale), 'Küchenwaage');
    expect(de.prettyDate(DateTime(2026, 8, 29)), '29. August');
    expect(en.prettyDate(DateTime(2026, 8, 29)), 'August 29');
    expect(en.updateNow, 'Update');
    expect(de.updateNow, 'Aktualisieren');
    expect(de.updateAvailableSubtitle('1.2.0'), contains('1.2.0'));
  });

  test('system locale de becomes German', () {
    expect(LocaleController.fromSystem(const Locale('de', 'DE')), AppLang.de);
    expect(LocaleController.fromSystem(const Locale('en', 'US')), AppLang.en);
  });
}
