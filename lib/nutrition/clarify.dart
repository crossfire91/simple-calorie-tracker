import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/nutrition/known_foods.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';

/// Only asks when the answer would swing calories by a lot (scoop size, 1 vs 2,
/// powder vs ready drink). Everyday clear plates stay quiet.
ClarificationQuestion? suggestClarification({
  required String note,
  required MealEstimate estimate,
  required S strings,
  ClarificationQuestion? fromModel,
  bool alreadyAnswered = false,
}) {
  if (alreadyAnswered) return null;
  if (fromModel != null && fromModel.usable) return fromModel;
  return _local(note, estimate, strings);
}

ClarificationQuestion? _local(String note, MealEstimate estimate, S strings) {
  final text = note.trim();
  if (text.isEmpty && estimate.items.isEmpty && estimate.unmatchedItems.isEmpty) {
    return null;
  }

  if (_hasConflictingScoopCount(text)) {
    return ClarificationQuestion(
      id: 'scoopCount',
      question: strings.scoopCountQuestion,
      options: [strings.oneScoop, strings.twoScoops],
    );
  }

  if (_hasScoop(text) && !_scoopHasGrams(text)) {
    return ClarificationQuestion(
      id: 'scoopWeight',
      question: strings.scoopWeightQuestion,
      options: const ['25g', '30g', '40g'],
    );
  }

  if (_hasUnspecifiedPlantMilk(text, estimate)) {
    return ClarificationQuestion(
      id: 'milkSweetness',
      question: strings.milkSweetnessQuestion,
      options: [strings.unsweetenedMilk, strings.sweetenedMilk],
    );
  }

  final unmatchedShake = estimate.unmatchedItems.cast<DetectedFood?>().firstWhere(
        (item) => item != null && _looksLikeShake(item),
        orElse: () => null,
      );
  if (unmatchedShake != null) {
    return ClarificationQuestion(
      id: 'shakeForm',
      question: strings.unmatchedShakeQuestion(unmatchedShake.name),
      options: [strings.proteinPowder, strings.readyShake],
    );
  }

  return null;
}

/// Tweaks the matching line only. Returns null when a full re-estimate is needed.
MealEstimate? applyClarification({
  required MealEstimate estimate,
  required ClarificationQuestion question,
  required String option,
  required S strings,
}) {
  switch (question.id) {
    case 'milkSweetness':
      final index = _indexWhere(
        estimate,
        (item) => isPlantMilkQuery('${item.queryEn} ${item.name}'),
      );
      if (index == null) return null;
      final sweetened = option == strings.sweetenedMilk;
      final food = estimate.items[index].detected;
      final per100 = typicalPlantMilkKcalPer100g(food, sweetened: sweetened);
      if (per100 == null) return null;
      return estimate
          .replaceGrounded(index, kcalPer100g: per100)
          .copyWith(clearClarification: true);
    case 'scoopWeight':
      final grams = int.tryParse(option.replaceAll(RegExp(r'[^0-9]'), ''));
      final index = _powderIndex(estimate);
      if (grams == null || index == null) return null;
      final current = estimate.items[index].grams;
      final nextGrams = current >= 50 ? grams * 2 : grams;
      return estimate.replaceGrounded(index, grams: nextGrams).copyWith(clearClarification: true);
    case 'scoopCount':
      final index = _powderIndex(estimate);
      if (index == null) return null;
      final current = estimate.items[index].grams;
      final two = option == strings.twoScoops;
      final nextGrams = two
          ? (current <= 40 ? current * 2 : current)
          : (current >= 50 ? (current / 2).round() : current);
      return estimate.replaceGrounded(index, grams: nextGrams).copyWith(clearClarification: true);
    case 'shakeForm':
      final unmatched = estimate.unmatchedItems.indexWhere(_looksLikeShake);
      if (unmatched < 0) return null;
      final powder = option == strings.proteinPowder;
      return estimate
          .replaceUnmatched(unmatched, kcalPer100g: powder ? 370 : 48)
          .copyWith(clearClarification: true);
    default:
      return null;
  }
}

int? _indexWhere(MealEstimate estimate, bool Function(DetectedFood item) test) {
  final index = estimate.items.indexWhere((item) => test(item.detected));
  return index >= 0 ? index : null;
}

int? _powderIndex(MealEstimate estimate) {
  final byName = _indexWhere(estimate, _looksLikeShake);
  if (byName != null) return byName;
  final dense = estimate.items.indexWhere((item) => item.kcalPer100g >= 280);
  return dense >= 0 ? dense : null;
}

bool _hasScoop(String note) {
  return RegExp(
    r'\b(scoops?|messl[oö]ffel|löffelvoll)\b',
    caseSensitive: false,
  ).hasMatch(note);
}

bool _scoopHasGrams(String note) {
  return RegExp(
    r'(\d+(?:[.,]\d+)?\s*g.{0,16}(scoops?|messl[oö]ffel))|((scoops?|messl[oö]ffel).{0,16}\d+(?:[.,]\d+)?\s*g)',
    caseSensitive: false,
  ).hasMatch(note);
}

bool _hasConflictingScoopCount(String note) {
  final doubled = RegExp(
    r'\b(doppelt\w*|double|zwei\s*(scoops?|messl)|2\s*scoops?)\b',
    caseSensitive: false,
  ).hasMatch(note);
  final single = RegExp(
    r'\b(1\s*scoops?|ein(?:en)?\s*(scoop|messl)|one\s*scoop)\b',
    caseSensitive: false,
  ).hasMatch(note);
  return doubled && single;
}

bool _hasUnspecifiedPlantMilk(String note, MealEstimate estimate) {
  if (mentionsSweetness(note)) return false;
  final foods = [...estimate.items.map((item) => item.detected), ...estimate.unmatchedItems];
  return foods.any((item) => item.grams >= 200 && prefersUnsweetenedPlantMilk(item));
}

bool _looksLikeShake(DetectedFood item) {
  final hay = '${item.name} ${item.queryEn} ${item.brandHint}'.toLowerCase();
  return hay.contains('shake') ||
      hay.contains('protein') ||
      hay.contains('whey') ||
      hay.contains('pulver');
}
