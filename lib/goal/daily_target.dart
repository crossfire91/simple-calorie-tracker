/// Daily energy target from current clinical practice.
///
/// BMR: Mifflin–St Jeor (Academy of Nutrition and Dietetics — best
/// non-lab estimate for adults, using actual body weight).
///
/// TDEE: BMR × PAL (FAO/WHO and ACSM activity factors).
///
/// Loss pace: 0.25–1.0 kg/week (Harvard, ACSM, AND: ~0.5–1 kg is the
/// usual safe band). 7700 kcal ≈ 1 kg adipose tissue (clinical planning).
///
/// Safety, applied automatically:
/// - never below estimated BMR
/// - never below AND self-guided floors (1200 / 1500 kcal)
/// - deficit capped at 25% of TDEE
/// - weekly loss capped at 1% of body weight (and never above 1 kg)
/// - BMI < 18.5 cannot use a deficit
class DailyTargetProfile {
  TargetMode mode;
  GoalType goal;
  BiologicalSex? sex;
  int? age;
  double? heightCm;
  double? weightKg;
  ActivityLevel activity;
  double paceKgPerWeek;
  int? manualKcal;

  DailyTargetProfile({
    this.mode = TargetMode.calculated,
    this.goal = GoalType.lose,
    this.sex,
    this.age,
    this.heightCm,
    this.weightKg,
    this.activity = ActivityLevel.light,
    this.paceKgPerWeek = 0.5,
    this.manualKcal,
  });

  DailyTargetProfile copy() => copyWith();

  DailyTargetProfile copyWith({
    TargetMode? mode,
    GoalType? goal,
    BiologicalSex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    double? paceKgPerWeek,
    int? manualKcal,
  }) {
    return DailyTargetProfile(
      mode: mode ?? this.mode,
      goal: goal ?? this.goal,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activity: activity ?? this.activity,
      paceKgPerWeek: paceKgPerWeek ?? this.paceKgPerWeek,
      manualKcal: manualKcal ?? this.manualKcal,
    );
  }

  factory DailyTargetProfile.fresh() => DailyTargetProfile();
}

enum TargetMode { calculated, manual }

enum GoalType { lose, maintain, gain }

enum BiologicalSex { female, male, unspecified }

enum ActivityLevel { sedentary, light, moderate, active, extra }

enum TargetNote {
  manualLow,
  maintain,
  underweightBlocked,
  loseCappedDeficit,
  loseCappedFloor,
  loseCappedPace,
  loseOk,
  gainCapped,
  gainOk,
}

class DailyTargetResult {
  final int targetKcal;
  final double bmr;
  final double tdee;
  final double plannedKgPerWeek;
  final bool wasCapped;
  final bool underweightBlocked;
  final TargetNote? noteKind;

  const DailyTargetResult({
    required this.targetKcal,
    required this.bmr,
    required this.tdee,
    required this.plannedKgPerWeek,
    this.wasCapped = false,
    this.underweightBlocked = false,
    this.noteKind,
  });
}

class DailyTargetMath {
  static const kcalPerKgFat = 7700.0;
  static const maxDeficitFraction = 0.25;
  static const maxSurplusFraction = 0.20;
  static const minAge = 16;
  static const maxAge = 90;
  static const minHeightCm = 120.0;
  static const maxHeightCm = 230.0;
  static const minWeightKg = 35.0;
  static const maxWeightKg = 250.0;

  static const losePaces = [0.25, 0.5, 0.75, 1.0];
  static const gainPaces = [0.15, 0.25, 0.4, 0.5];

  static double pal(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.extra:
        return 1.9;
    }
  }

  static double bmr({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    switch (sex) {
      case BiologicalSex.male:
        return base + 5;
      case BiologicalSex.female:
        return base - 161;
      case BiologicalSex.unspecified:
        return base - 78;
    }
  }

  static int floorKcal(BiologicalSex? sex) {
    switch (sex) {
      case BiologicalSex.female:
        return 1200;
      case BiologicalSex.male:
        return 1500;
      case BiologicalSex.unspecified:
      case null:
        return 1300;
    }
  }

  static double bmi(double weightKg, double heightCm) {
    final m = heightCm / 100;
    return weightKg / (m * m);
  }

  static double maxHealthyLossKg(double weightKg, double bodyMassIndex) {
    if (bodyMassIndex < 18.5) return 0;
    final byPercent = weightKg * 0.01;
    return byPercent < 1.0 ? byPercent : 1.0;
  }

  static double maxHealthyGainKg(double weightKg) {
    final byPercent = weightKg * 0.005;
    return byPercent < 0.5 ? byPercent : 0.5;
  }

  static ({double kg, TargetNote note}) _tightestLossCap({
    required double onePercentKg,
    required double deficitKg,
    required double floorKg,
  }) {
    var kg = onePercentKg;
    var note = TargetNote.loseCappedPace;
    if (deficitKg < kg) {
      kg = deficitKg;
      note = TargetNote.loseCappedDeficit;
    }
    if (floorKg < kg) {
      kg = floorKg;
      note = TargetNote.loseCappedFloor;
    }
    return (kg: kg, note: note);
  }

  static bool rangesOk(DailyTargetProfile profile) {
    final age = profile.age;
    final height = profile.heightCm;
    final weight = profile.weightKg;
    if (age == null || height == null || weight == null) return false;
    return age >= minAge &&
        age <= maxAge &&
        height >= minHeightCm &&
        height <= maxHeightCm &&
        weight >= minWeightKg &&
        weight <= maxWeightKg;
  }

  static DailyTargetResult? tryCalculate(DailyTargetProfile profile) {
    if (profile.mode == TargetMode.manual) {
      final kcal = profile.manualKcal ?? 2200;
      if (kcal < 800 || kcal > 6000) return null;
      return DailyTargetResult(
        targetKcal: kcal,
        bmr: 0,
        tdee: 0,
        plannedKgPerWeek: 0,
        noteKind: kcal < floorKcal(profile.sex) ? TargetNote.manualLow : null,
      );
    }

    final sex = profile.sex;
    if (sex == null || !rangesOk(profile)) return null;

    final weight = profile.weightKg!;
    final height = profile.heightCm!;
    final age = profile.age!;
    final resting = bmr(sex: sex, weightKg: weight, heightCm: height, age: age);
    final tdee = resting * pal(profile.activity);
    final bodyMassIndex = bmi(weight, height);
    final floor = [resting.round(), floorKcal(sex)].reduce((a, b) => a > b ? a : b);

    if (profile.goal == GoalType.maintain) {
      return DailyTargetResult(
        targetKcal: tdee.round(),
        bmr: resting,
        tdee: tdee,
        plannedKgPerWeek: 0,
        noteKind: TargetNote.maintain,
      );
    }

    if (profile.goal == GoalType.lose) {
      if (bodyMassIndex < 18.5) {
        return DailyTargetResult(
          targetKcal: tdee.round(),
          bmr: resting,
          tdee: tdee,
          plannedKgPerWeek: 0,
          underweightBlocked: true,
          noteKind: TargetNote.underweightBlocked,
        );
      }

      final onePercentKg = maxHealthyLossKg(weight, bodyMassIndex);
      final deficitKg = (tdee * maxDeficitFraction * 7) / kcalPerKgFat;
      final floorKg = ((tdee - floor) * 7) / kcalPerKgFat;
      final wantKg = profile.paceKgPerWeek;

      var limitedKg = wantKg;
      TargetNote? capKind;
      final binding = _tightestLossCap(
        onePercentKg: onePercentKg,
        deficitKg: deficitKg,
        floorKg: floorKg,
      );
      if (wantKg > binding.kg + 0.001) {
        limitedKg = binding.kg;
        capKind = binding.note;
      }

      var target = (tdee - (limitedKg * kcalPerKgFat) / 7).round();
      if (target < floor) {
        target = floor;
        capKind = TargetNote.loseCappedFloor;
      }

      final actualKg = ((tdee - target) * 7) / kcalPerKgFat;
      return DailyTargetResult(
        targetKcal: target,
        bmr: resting,
        tdee: tdee,
        plannedKgPerWeek: actualKg,
        wasCapped: capKind != null,
        noteKind: capKind ?? TargetNote.loseOk,
      );
    }

    var wantKg = profile.paceKgPerWeek;
    final allowedGain = maxHealthyGainKg(weight);
    var capped = false;
    if (wantKg > allowedGain) {
      wantKg = allowedGain;
      capped = true;
    }

    var surplus = (wantKg * kcalPerKgFat) / 7;
    final maxSurplus = tdee * maxSurplusFraction;
    if (surplus > maxSurplus) {
      surplus = maxSurplus;
      capped = true;
    }

    final target = (tdee + surplus).round();
    final actualKg = ((target - tdee) * 7) / kcalPerKgFat;
    return DailyTargetResult(
      targetKcal: target,
      bmr: resting,
      tdee: tdee,
      plannedKgPerWeek: actualKg,
      wasCapped: capped,
      noteKind: capped ? TargetNote.gainCapped : TargetNote.gainOk,
    );
  }
}
