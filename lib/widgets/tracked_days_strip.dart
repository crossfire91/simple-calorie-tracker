import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/habit/streak.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class TrackedDaysStrip extends StatelessWidget {
  final Set<String> trackedDateKeys;
  final Map<String, DayDigest> digests;
  final int kcalBudget;
  final int days;

  const TrackedDaysStrip({
    super.key,
    required this.trackedDateKeys,
    this.digests = const {},
    this.kcalBudget = 0,
    this.days = 21,
  });

  @override
  Widget build(BuildContext context) {
    final window = JourneyMath.lastDays(days);
    final mealKeys = StreakMath.mealKeys(digests);
    final streak = StreakMath.currentStreak(mealKeys);
    final closed = window.where((d) {
      return StreakMath.tone(digests[JourneyMath.dateKey(d)], kcalBudget) ==
          DayTone.closed;
    }).length;
    final today = JourneyMath.dayOnly(DateTime.now());
    final s = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.daysYouShowedUp, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            _StreakChip(label: s.streakLabel(streak), hot: streak > 0),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: window.map((date) {
            final key = JourneyMath.dateKey(date);
            final digest = digests[key];
            final tone = StreakMath.tone(digest, kcalBudget);
            final weighedOnly = tone == DayTone.empty &&
                (trackedDateKeys.contains(key) || (digest?.hasWeight ?? false));
            final isToday = date == today;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: _fill(tone, weighedOnly),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isToday
                            ? AppColors.accentSoft.withOpacity(0.7)
                            : AppColors.stroke,
                      ),
                      boxShadow: tone == DayTone.closed
                          ? AppColors.glow(AppColors.mint, 0.16)
                          : tone == DayTone.over
                              ? AppColors.glow(AppColors.coral, 0.12)
                              : null,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          closed > 0
              ? '${s.trackedDaysHint} · ${s.ringsClosed(closed)}'
              : s.trackedDaysHint,
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Color _fill(DayTone tone, bool weighedOnly) {
    switch (tone) {
      case DayTone.closed:
        return AppColors.mint;
      case DayTone.under:
        return const Color(0xFF3D8F7A);
      case DayTone.over:
        return AppColors.coral;
      case DayTone.empty:
        return weighedOnly ? const Color(0xFF2A3A52) : AppColors.surfaceHigh;
    }
  }
}

class _StreakChip extends StatelessWidget {
  final String label;
  final bool hot;

  const _StreakChip({required this.label, required this.hot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: hot ? AppColors.gradient : null,
        color: hot ? null : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hot ? Colors.transparent : AppColors.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: hot ? Colors.white : AppColors.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
