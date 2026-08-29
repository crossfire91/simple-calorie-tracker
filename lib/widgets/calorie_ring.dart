import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/ring_burst.dart';

class CalorieRing extends StatefulWidget {
  final double consumed;
  final int budget;
  final double ghostConsumed;
  final bool celebrate;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.budget,
    this.ghostConsumed = 0,
    this.celebrate = false,
  });

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  double _from = 0;

  double _progressOf(double consumed, int budget) {
    if (budget <= 0) return 0;
    return (consumed / budget).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _from = _progressOf(widget.consumed, widget.budget);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.celebrate) {
      _pulse.forward();
    }
  }

  @override
  void didUpdateWidget(covariant CalorieRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumed != widget.consumed || oldWidget.budget != widget.budget) {
      _from = _progressOf(oldWidget.consumed, oldWidget.budget);
    }
    if (widget.celebrate && !oldWidget.celebrate) {
      _pulse.forward(from: 0);
    } else if (!widget.celebrate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.budget - widget.consumed;
    final over = remaining < 0;
    final closed = widget.budget > 0 && widget.consumed >= widget.budget;
    final progress = widget.budget == 0 ? 0.0 : (widget.consumed / widget.budget).clamp(0.0, 1.2);
    final displayProgress = progress.clamp(0.0, 1.0);
    final ghostProgress = widget.budget == 0
        ? 0.0
        : (widget.ghostConsumed / widget.budget).clamp(0.0, 1.0);
    final s = S.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: displayProgress),
      duration: const Duration(milliseconds: 980),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final beat = closed ? 1 + (_pulse.value * 0.035) : 1.0;
            return SizedBox(
              width: 208,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: beat,
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: _RingPainter(
                        progress: value,
                        ghost: ghostProgress,
                        over: over,
                        closed: closed,
                      ),
                    ),
                  ),
                  if (widget.celebrate) const Positioned.fill(child: RingBurst()),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        remaining.abs().toStringAsFixed(0),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 40,
                              color: over ? AppColors.coralSoft : AppColors.text,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        closed && !over
                            ? s.ringClosed
                            : over
                                ? s.overBudget
                                : s.kcalLeft,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: over
                                  ? AppColors.coral
                                  : closed
                                      ? AppColors.mint
                                      : AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.consumed.toStringAsFixed(0)} / ${widget.budget}',
                        style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.ghostConsumed > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${s.yesterdayGhost} ${widget.ghostConsumed.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double ghost;
  final bool over;
  final bool closed;

  _RingPainter({
    required this.progress,
    required this.ghost,
    required this.over,
    required this.closed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const stroke = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final ghostRect = Rect.fromCircle(center: center, radius: radius + 11);

    if (ghost > 0) {
      final ghostTrack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFF2A3344);
      canvas.drawCircle(center, radius + 11, ghostTrack);
      final ghostSweep = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.22);
      canvas.drawArc(ghostRect, -math.pi / 2, math.pi * 2 * ghost, false, ghostSweep);
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = (over ? AppColors.coral : closed ? AppColors.mint : AppColors.accent)
          .withOpacity(closed ? 0.28 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, glow);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF243044);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final colors = over
        ? const [AppColors.coralSoft, AppColors.rose]
        : closed
            ? const [AppColors.mint, AppColors.accentSoft, AppColors.accent]
            : const [AppColors.accentSoft, AppColors.accent, AppColors.mint];

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: colors,
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ghost != ghost ||
        oldDelegate.over != over ||
        oldDelegate.closed != closed;
  }
}
