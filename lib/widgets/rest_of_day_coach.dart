import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/habit/rest_of_day.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class RestOfDayCoach extends StatelessWidget {
  final double consumed;
  final int budget;
  final List<FavoriteMeal> favorites;
  final List<FavoriteMeal> recent;
  final List<LoggedBite> meals;
  final double? weightKg;
  final DateTime? now;
  final bool isToday;
  final bool embedded;
  final ValueChanged<FavoriteMeal>? onLogFavorite;
  final VoidCallback? onAdd;

  const RestOfDayCoach({
    super.key,
    required this.consumed,
    required this.budget,
    this.favorites = const [],
    this.recent = const [],
    this.meals = const [],
    this.weightKg,
    this.now,
    this.isToday = true,
    this.embedded = false,
    this.onLogFavorite,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (!isToday) return const SizedBox.shrink();
    final plan = RestOfDayMath.plan(
      consumed: consumed,
      budget: budget,
      favorites: favorites,
      recent: recent,
      meals: meals,
      weightKg: weightKg,
      now: now,
    );
    final accent = _accentFor(plan.mood);
    final body = _CoachBody(
      plan: plan,
      accent: accent,
      favorites: favorites,
      recent: recent,
      onLogFavorite: onLogFavorite,
      onAdd: onAdd,
    );
    if (embedded) return body;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF182232), AppColors.surface, Color(0xFF10161F)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
            Positioned(
              right: -40,
              top: -50,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [accent.withOpacity(0.22), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: body,
            ),
          ],
        ),
      ),
    );
  }

  Color _accentFor(CoachMood mood) {
    switch (mood) {
      case CoachMood.over:
        return AppColors.rose;
      case CoachMood.closed:
        return AppColors.mint;
      case CoachMood.proteinPush:
        return AppColors.coralSoft;
      case CoachMood.morningOpen:
        return AppColors.accentSoft;
      case CoachMood.dinner:
      case CoachMood.latePlate:
        return const Color(0xFFB388FF);
      case CoachMood.lateSip:
      case CoachMood.nextPlate:
        return AppColors.mint;
    }
  }
}

class _CoachBody extends StatelessWidget {
  final RestOfDayPlan plan;
  final Color accent;
  final List<FavoriteMeal> favorites;
  final List<FavoriteMeal> recent;
  final ValueChanged<FavoriteMeal>? onLogFavorite;
  final VoidCallback? onAdd;

  const _CoachBody({
    required this.plan,
    required this.accent,
    required this.favorites,
    this.recent = const [],
    this.onLogFavorite,
    this.onAdd,
  });

  FavoriteMeal? _match(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final fav in favorites) {
      if (fav.id == id) return fav;
    }
    for (final meal in recent) {
      if (meal.id == id) return meal;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final taps = plan.tapSuggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.coachEyebrow(plan.mood),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                letterSpacing: 1.6,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          s.coachLine(plan),
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.32,
            letterSpacing: -0.3,
          ),
        ),
        if (taps.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final item in taps)
            _FillRow(
              name: s.servingsOf(item.label(s.isDe), item.servings),
              kcal: item.kcal,
              accent: accent,
              onTap: onLogFavorite == null
                  ? null
                  : () {
                      final match = _match(item.favoriteId);
                      if (match == null) return;
                      HapticFeedback.mediumImpact();
                      onLogFavorite!(match);
                    },
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              s.restTogether(plan.filledKcal, plan.leftoverAfterPlan),
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (onAdd != null) ...[
          const SizedBox(height: 10),
          _CoachChip(
            label: s.coachAdd,
            accent: AppColors.accent,
            filled: true,
            onTap: onAdd,
          ),
        ],
      ],
    );
  }
}

class _FillRow extends StatelessWidget {
  final String name;
  final int kcal;
  final Color accent;
  final VoidCallback? onTap;

  const _FillRow({
    required this.name,
    required this.kcal,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$kcal kcal',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachChip extends StatelessWidget {
  final String label;
  final Color accent;
  final int? kcal;
  final bool filled;
  final VoidCallback? onTap;

  const _CoachChip({
    required this.label,
    required this.accent,
    this.kcal,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: filled ? accent : accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: filled ? Colors.transparent : accent.withOpacity(0.35)),
          ),
          child: Text(
            kcal == null ? label : '$label · $kcal',
            style: TextStyle(
              color: filled ? AppColors.text : accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
