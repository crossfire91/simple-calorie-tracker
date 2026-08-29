import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';

enum DayTone { empty, under, closed, over }

class StreakMath {
  static String dateKey(DateTime date) => JourneyMath.dateKey(date);

  static DateTime dayOnly(DateTime date) => JourneyMath.dayOnly(date);

  static Set<String> mealKeys(Map<String, DayDigest> digests) {
    return {
      for (final entry in digests.entries)
        if (entry.value.hasMeals) entry.key,
    };
  }

  static Set<String> currentStreakKeys(
    Set<String> mealDays, {
    DateTime? now,
  }) {
    if (mealDays.isEmpty) return {};
    final today = dayOnly(now ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime cursor;
    if (mealDays.contains(dateKey(today))) {
      cursor = today;
    } else if (mealDays.contains(dateKey(yesterday))) {
      cursor = yesterday;
    } else {
      return {};
    }

    final keys = <String>{};
    while (mealDays.contains(dateKey(cursor))) {
      keys.add(dateKey(cursor));
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return keys;
  }

  static int currentStreak(
    Set<String> mealDays, {
    DateTime? now,
  }) {
    return currentStreakKeys(mealDays, now: now).length;
  }

  static DayTone tone(DayDigest? digest, int budget) {
    if (digest == null || !digest.hasMeals) return DayTone.empty;
    if (budget <= 0) return DayTone.under;
    final ratio = digest.kcal / budget;
    if (ratio > 1.05) return DayTone.over;
    if (ratio >= 0.95) return DayTone.closed;
    return DayTone.under;
  }

  static bool ringJustClosed(double before, double after, int budget) {
    if (budget <= 0) return false;
    return before < budget && after >= budget;
  }
}
