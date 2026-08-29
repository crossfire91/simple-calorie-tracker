import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class RelativeDayChip extends StatelessWidget {
  final DateTime date;

  const RelativeDayChip({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isToday = JourneyMath.sameDay(date, DateTime.now());
    final isPast = JourneyMath.dayOnly(date).isBefore(JourneyMath.dayOnly(DateTime.now()));

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isToday ? AppColors.accent.withOpacity(0.16) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday
                ? AppColors.accentSoft.withOpacity(0.55)
                : AppColors.stroke,
          ),
          boxShadow: isToday ? AppColors.glow(AppColors.accent, 0.12) : null,
        ),
        child: Padding(
          key: const Key('relative-day-chip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            s.relativeDay(date),
            style: TextStyle(
              color: isToday
                  ? AppColors.accentSoft
                  : isPast
                      ? AppColors.textMuted
                      : AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
