import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class WeightSparkline extends StatelessWidget {
  final List<WeightEntry> logs;
  final GoalType goal;
  final double plannedKgPerWeek;

  const WeightSparkline({
    super.key,
    required this.logs,
    required this.goal,
    required this.plannedKgPerWeek,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          logs: logs,
          goal: goal,
          plannedKgPerWeek: plannedKgPerWeek,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<WeightEntry> logs;
  final GoalType goal;
  final double plannedKgPerWeek;

  _SparklinePainter({
    required this.logs,
    required this.goal,
    required this.plannedKgPerWeek,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    final start = JourneyMath.parseDateKey(logs.first.dateKey);
    final lastActual = JourneyMath.parseDateKey(logs.last.dateKey);
    final horizon = logs.length == 1
        ? start.add(const Duration(days: 28))
        : lastActual.isAfter(start.add(const Duration(days: 7)))
            ? lastActual
            : start.add(const Duration(days: 14));
    final spanDays = math.max(horizon.difference(start).inDays, 1);

    final expectedPoints = <double>[];
    for (var i = 0; i <= spanDays; i += math.max(1, (spanDays / 12).ceil())) {
      expectedPoints.add(
        JourneyMath.expectedWeight(
          startKg: logs.first.weightKg,
          startDate: start,
          onDate: start.add(Duration(days: i)),
          goal: goal,
          plannedKgPerWeek: plannedKgPerWeek,
        ),
      );
    }
    expectedPoints.add(
      JourneyMath.expectedWeight(
        startKg: logs.first.weightKg,
        startDate: start,
        onDate: horizon,
        goal: goal,
        plannedKgPerWeek: plannedKgPerWeek,
      ),
    );

    final weights = [
      ...logs.map((e) => e.weightKg),
      ...expectedPoints,
    ];
    var minW = weights.reduce(math.min);
    var maxW = weights.reduce(math.max);
    if ((maxW - minW).abs() < 0.6) {
      minW -= 0.4;
      maxW += 0.4;
    } else {
      final pad = (maxW - minW) * 0.18;
      minW -= pad;
      maxW += pad;
    }

    Offset pointFor(DateTime date, double kg) {
      final t = date.difference(start).inDays / spanDays;
      final y = 1 - ((kg - minW) / (maxW - minW));
      return Offset(
        10 + t.clamp(0.0, 1.0) * (size.width - 20),
        12 + y.clamp(0.0, 1.0) * (size.height - 28),
      );
    }

    final expectedPath = Path();
    for (var i = 0; i <= spanDays; i++) {
      final p = pointFor(
        start.add(Duration(days: i)),
        JourneyMath.expectedWeight(
          startKg: logs.first.weightKg,
          startDate: start,
          onDate: start.add(Duration(days: i)),
          goal: goal,
          plannedKgPerWeek: plannedKgPerWeek,
        ),
      );
      if (i == 0) {
        expectedPath.moveTo(p.dx, p.dy);
      } else {
        expectedPath.lineTo(p.dx, p.dy);
      }
    }

    final expectedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withOpacity(0.18);
    canvas.drawPath(
      expectedPath,
      expectedPaint
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.mint.withOpacity(0.35);
    _drawDashed(canvas, expectedPath, dash);

    final actual = logs
        .map((e) => pointFor(JourneyMath.parseDateKey(e.dateKey), e.weightKg))
        .toList();

    if (actual.length == 1) {
      _glowDot(canvas, actual.first, 7);
      return;
    }

    final line = Path()..moveTo(actual.first.dx, actual.first.dy);
    for (var i = 1; i < actual.length; i++) {
      final prev = actual[i - 1];
      final curr = actual[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      line.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    line.lineTo(actual.last.dx, actual.last.dy);

    final fill = Path.from(line)
      ..lineTo(actual.last.dx, size.height - 4)
      ..lineTo(actual.first.dx, size.height - 4)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accentSoft.withOpacity(0.32),
          AppColors.accent.withOpacity(0.02),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fill, fillPaint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentSoft.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(line, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: const [AppColors.accentSoft, AppColors.mint],
      ).createShader(Offset.zero & size);
    canvas.drawPath(line, stroke);

    for (var i = 0; i < actual.length; i++) {
      _glowDot(canvas, actual[i], i == actual.length - 1 ? 6.5 : 4.2);
    }
  }

  void _glowDot(Canvas canvas, Offset p, double r) {
    canvas.drawCircle(
      p,
      r + 6,
      Paint()
        ..color = AppColors.accentSoft.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(p, r, Paint()..color = Colors.white);
    canvas.drawCircle(p, r - 1.6, Paint()..color = AppColors.accentSoft);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.logs != logs ||
        oldDelegate.goal != goal ||
        oldDelegate.plannedKgPerWeek != plannedKgPerWeek;
  }
}
