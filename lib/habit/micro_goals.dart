import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';

enum MicroGoalId { breakfast, protein, noLate }

enum MicroGoalState { open, done, missed }

class LoggedBite {
  final String name;
  final double kcal;
  final double proteinG;
  final DateTime? loggedAt;

  const LoggedBite({
    required this.name,
    required this.kcal,
    this.proteinG = 0,
    this.loggedAt,
  });
}

class MicroGoal {
  final MicroGoalId id;
  final MicroGoalState state;
  final double progress;

  const MicroGoal({
    required this.id,
    required this.state,
    required this.progress,
  });

  bool get done => state == MicroGoalState.done;
}

class MicroGoalsSnapshot {
  final MicroGoal breakfast;
  final MicroGoal protein;
  final MicroGoal noLate;
  final int proteinGrams;
  final int proteinTarget;

  const MicroGoalsSnapshot({
    required this.breakfast,
    required this.protein,
    required this.noLate,
    required this.proteinGrams,
    required this.proteinTarget,
  });

  List<MicroGoal> get all => [breakfast, protein, noLate];
}

class MicroGoalMath {
  static const breakfastHour = 11;
  static const lateHour = 21;

  static MicroGoalsSnapshot fromMeals(
    List<LoggedBite> meals, {
    double? weightKg,
    DateTime? now,
    DateTime? forDay,
  }) {
    final clock = now ?? DateTime.now();
    final day = JourneyMath.dayOnly(forDay ?? clock);
    final live = JourneyMath.sameDay(day, clock);
    final evaluating = live
        ? clock
        : DateTime(day.year, day.month, day.day, 23, 59);

    final proteinTarget = ProteinMath.dailyTargetGrams(weightKg);
    final proteinGrams = meals.fold<double>(0, (sum, meal) {
      final stored = meal.proteinG;
      if (stored > 0) return sum + stored;
      return sum + ProteinMath.estimateGrams(name: meal.name, kcal: meal.kcal);
    }).round();

    return MicroGoalsSnapshot(
      breakfast: _breakfast(meals, evaluating),
      protein: _protein(proteinGrams, proteinTarget),
      noLate: _noLate(meals, evaluating),
      proteinGrams: proteinGrams,
      proteinTarget: proteinTarget,
    );
  }

  static MicroGoal _breakfast(List<LoggedBite> meals, DateTime clock) {
    if (meals.isEmpty) {
      return const MicroGoal(
        id: MicroGoalId.breakfast,
        state: MicroGoalState.open,
        progress: 0,
      );
    }

    final timed = meals.where((m) => m.loggedAt != null).toList();
    final early = timed.any((m) => m.loggedAt!.hour < breakfastHour);
    final onlyLateMeals = timed.isNotEmpty && timed.every((m) => m.loggedAt!.hour >= breakfastHour);
    if (early || timed.isEmpty) {
      return const MicroGoal(
        id: MicroGoalId.breakfast,
        state: MicroGoalState.done,
        progress: 1,
      );
    }
    if (onlyLateMeals) {
      return const MicroGoal(
        id: MicroGoalId.breakfast,
        state: MicroGoalState.missed,
        progress: 0,
      );
    }
    return const MicroGoal(
      id: MicroGoalId.breakfast,
      state: MicroGoalState.open,
      progress: 0,
    );
  }

  static MicroGoal _protein(int grams, int target) {
    final progress = target <= 0 ? 0.0 : (grams / target).clamp(0.0, 1.2);
    return MicroGoal(
      id: MicroGoalId.protein,
      state: progress >= 0.9 ? MicroGoalState.done : MicroGoalState.open,
      progress: progress.clamp(0.0, 1.0),
    );
  }

  static MicroGoal _noLate(List<LoggedBite> meals, DateTime clock) {
    final late = meals.any(
      (m) => m.loggedAt != null && m.loggedAt!.hour >= lateHour,
    );
    if (late) {
      return const MicroGoal(
        id: MicroGoalId.noLate,
        state: MicroGoalState.missed,
        progress: 0,
      );
    }
    if (clock.hour >= lateHour) {
      return const MicroGoal(
        id: MicroGoalId.noLate,
        state: MicroGoalState.done,
        progress: 1,
      );
    }
    return const MicroGoal(
      id: MicroGoalId.noLate,
      state: MicroGoalState.open,
      progress: 0,
    );
  }
}
