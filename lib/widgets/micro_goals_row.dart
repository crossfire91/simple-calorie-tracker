import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class MicroGoalsRow extends StatelessWidget {
  final MicroGoalsSnapshot snapshot;
  final bool embedded;
  final String? title;

  const MicroGoalsRow({
    super.key,
    required this.snapshot,
    this.embedded = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title ?? s.microGoals, style: Theme.of(context).textTheme.labelSmall),
          ),
          Row(
            children: [
              Expanded(
                child: _GoalCell(
                  label: s.breakfastGoal,
                  goal: snapshot.breakfast,
                  caption: snapshot.breakfast.done ? '✓' : '',
                ),
              ),
              Expanded(
                child: _GoalCell(
                  label: s.proteinGoal,
                  goal: snapshot.protein,
                  caption: s.proteinGoalLine(snapshot.proteinGrams, snapshot.proteinTarget),
                ),
              ),
              Expanded(
                child: _GoalCell(
                  label: s.noLateGoal,
                  goal: snapshot.noLate,
                  caption: snapshot.noLate.state == MicroGoalState.missed ? '✕' : '',
                ),
              ),
            ],
          ),
        ],
    );

    if (embedded) return body;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: body,
    );
  }
}

class _GoalCell extends StatelessWidget {
  final String label;
  final MicroGoal goal;
  final String caption;

  const _GoalCell({
    required this.label,
    required this.goal,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (goal.state) {
      MicroGoalState.done => AppColors.mint,
      MicroGoalState.missed => AppColors.coralSoft,
      MicroGoalState.open => AppColors.accentSoft,
    };

    return Column(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CustomPaint(
            painter: _MiniGoalPainter(progress: goal.progress, color: color),
            child: Center(
              child: Icon(
                switch (goal.id) {
                  MicroGoalId.breakfast => Icons.wb_sunny_rounded,
                  MicroGoalId.protein => Icons.lunch_dining_rounded,
                  MicroGoalId.noLate => Icons.nights_stay_rounded,
                },
                size: 18,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniGoalPainter extends CustomPainter {
  final double progress;
  final Color color;

  _MiniGoalPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF243044);
    canvas.drawCircle(center, radius, track);
    if (progress <= 0) return;
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniGoalPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
