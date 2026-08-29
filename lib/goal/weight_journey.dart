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
      profile.mode == TargetMode.calculated && result != null;

  bool get showLossSupport => visible && profile.goal == GoalType.lose;

  double? get currentKg =>
      logs.isNotEmpty ? logs.last.weightKg : profile.weightKg;

  double? get startKg =>
      logs.isNotEmpty ? logs.first.weightKg : profile.weightKg;

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
    if (profile.mode != TargetMode.calculated) return null;
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

  static PaceHint paceHint({
    required GoalType goal,
    required double startKg,
    required double currentKg,
    required DateTime startDate,
    required DateTime onDate,
    required double plannedKgPerWeek,
  }) {
    if (goal == GoalType.maintain) {
      final drift = currentKg - startKg;
      if (drift.abs() < 0.35) return PaceHint.holdSteady;
      return drift > 0 ? PaceHint.holdUp : PaceHint.holdDown;
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
    if (kindGap < 0) return PaceHint.ahead;
    return PaceHint.behind;
  }
}

enum PaceHint { holdSteady, holdUp, holdDown, onPace, ahead, behind }
