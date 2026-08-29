import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class WeightInsightBanner extends StatelessWidget {
  final DailyTargetResult result;
  final GoalType goal;
  final double currentKg;
  final VoidCallback? onTap;

  const WeightInsightBanner({
    super.key,
    required this.result,
    required this.goal,
    required this.currentKg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final week = result.plannedKgPerWeek;
    final holding = goal == GoalType.maintain;
    final gaining = !holding && goal == GoalType.gain;
    final icon = holding
        ? Icons.favorite_rounded
        : gaining
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;
    final color = holding
        ? AppColors.mint
        : gaining
            ? AppColors.accentSoft
            : AppColors.coralSoft;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.28)),
          boxShadow: AppColors.glow(color, 0.12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.trendLabel(goal, week)}  ·  ${s.weekLine(goal, week)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.atKgKcal(currentKg, result.targetKcal),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
