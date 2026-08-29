import 'package:simple_calorie_tracker/goal/daily_target.dart';

class WeightEntry {
  final String id;
  final String dateKey;
  final double weightKg;

  const WeightEntry({
    required this.id,
    required this.dateKey,
    required this.weightKg,
  });
}

class WeightSnapshot {
  final DailyTargetProfile profile;
  final DailyTargetResult? result;
  final List<WeightEntry> logs;
  final Set<String> trackedDateKeys;

  const WeightSnapshot({
    required this.profile,
    required this.result,
    required this.logs,
    required this.trackedDateKeys,
  });

  bool get visible =>
      profile.mode == TargetMode.manual || result != null;

  bool get showLossSupport =>
      visible &&
      profile.mode == TargetMode.calculated &&
      profile.goal == GoalType.lose;

  double? get currentKg =>
      logs.isNotEmpty
          ? logs.last.weightKg
          : profile.mode == TargetMode.calculated
              ? profile.weightKg
              : null;

  double? get startKg =>
      logs.isNotEmpty
          ? logs.first.weightKg
          : profile.mode == TargetMode.calculated
              ? profile.weightKg
              : null;

  DateTime? get startedAt =>
      logs.isEmpty ? null : JourneyMath.parseDateKey(logs.first.dateKey);

  DateTime? get lastWeighIn =>
      logs.isEmpty ? null : JourneyMath.parseDateKey(logs.last.dateKey);

  double get deltaKg {
    final start = startKg;
    final current = currentKg;
    if (start == null || current == null) return 0;
    return current - start;
  }

  GoalType get journeyGoal => profile.goal;

  /// Intended weekly change, including a pace set with a fixed calorie
  /// number. The current-weight cap is ignored so a later underweight
  /// floor cannot rewrite a large loss as "maintain".
  double get journeyPaceKgPerWeek {
    if (profile.goal == GoalType.maintain) return 0;
    if (profile.mode == TargetMode.manual) return 0;
    if (profile.paceKgPerWeek > 0) return profile.paceKgPerWeek;
    return result?.plannedKgPerWeek ?? 0;
  }
}

class JourneyMath {
  static String dateKey(DateTime date) => '${date.day}.${date.month}.${date.year}';

  static DateTime parseDateKey(String key) {
    final parts = key.split('.');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  static DateTime dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime mondayOf(DateTime date) {
    final d = dayOnly(date);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static int isoWeek(DateTime date) {
    final d = dayOnly(date);
    final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
    return 1 + thursday.difference(DateTime(thursday.year, 1, 1)).inDays ~/ 7;
  }

  static List<WeightEntry> sortedLogs(Iterable<WeightEntry> logs) {
    final list = logs.toList();
    list.sort(
      (a, b) => parseDateKey(a.dateKey).compareTo(parseDateKey(b.dateKey)),
    );
    return list;
  }

  static DailyTargetResult? projection(
    DailyTargetProfile profile, {
    double? currentWeight,
  }) {
    final next = currentWeight == null
        ? profile
        : profile.copyWith(weightKg: currentWeight);
    return DailyTargetMath.tryCalculate(next);
  }

  static double expectedWeight({
    required double startKg,
    required DateTime startDate,
    required DateTime onDate,
    required GoalType goal,
    required double plannedKgPerWeek,
  }) {
    final start = dayOnly(startDate);
    final on = dayOnly(onDate);
    final days = on.difference(start).inDays;
    if (days <= 0 || plannedKgPerWeek <= 0) return startKg;
    final weeks = days / 7.0;
    switch (goal) {
      case GoalType.lose:
        return startKg - plannedKgPerWeek * weeks;
      case GoalType.gain:
        return startKg + plannedKgPerWeek * weeks;
      case GoalType.maintain:
        return startKg;
    }
  }

  static List<DateTime> lastDays(int count, [DateTime? from]) {
    final today = dayOnly(from ?? DateTime.now());
    return List.generate(
      count,
      (i) => today.subtract(Duration(days: count - 1 - i)),
    );
  }

  static double muchKg(double startKg) {
    final byPercent = startKg.abs() * 0.02;
    return byPercent > 2.5 ? byPercent : 2.5;
  }

  static PaceHint paceHint({
    required GoalType goal,
    required double startKg,
    required double currentKg,
    required DateTime startDate,
    required DateTime onDate,
    required double plannedKgPerWeek,
  }) {
    final drift = currentKg - startKg;
    if (drift.abs() < 0.35) return PaceHint.holdSteady;

    final much = muchKg(startKg);

    if (goal == GoalType.maintain) {
      if (drift.abs() < much) {
        return drift > 0 ? PaceHint.holdUp : PaceHint.holdDown;
      }
      return drift > 0 ? PaceHint.holdUpMuch : PaceHint.holdDownMuch;
    }

    if (plannedKgPerWeek <= 0) {
      final towardGoal = goal == GoalType.lose ? -drift : drift;
      if (towardGoal > 0) {
        return towardGoal >= much ? PaceHint.aheadMuch : PaceHint.ahead;
      }
      return towardGoal.abs() >= much ? PaceHint.behindMuch : PaceHint.behind;
    }

    final expected = expectedWeight(
      startKg: startKg,
      startDate: startDate,
      onDate: onDate,
      goal: goal,
      plannedKgPerWeek: plannedKgPerWeek,
    );
    final gap = currentKg - expected;
    final kindGap = goal == GoalType.lose ? gap : -gap;

    if (kindGap.abs() < 0.4) return PaceHint.onPace;
    if (kindGap < 0) {
      return kindGap.abs() >= much ? PaceHint.aheadMuch : PaceHint.ahead;
    }
    return kindGap >= much ? PaceHint.behindMuch : PaceHint.behind;
  }
}

enum PaceHint {
  holdSteady,
  holdUp,
  holdDown,
  holdUpMuch,
  holdDownMuch,
  onPace,
  ahead,
  aheadMuch,
  behind,
  behindMuch,
}
