import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/micro_goals_row.dart';

class DayPulseCard extends StatelessWidget {
  final MicroGoalsSnapshot snapshot;
  final String? title;

  const DayPulseCard({
    super.key,
    required this.snapshot,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: MicroGoalsRow(
        snapshot: snapshot,
        embedded: true,
        title: title ?? S.of(context).microGoals,
      ),
    );
  }
}
