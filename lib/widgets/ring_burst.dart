import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class RingBurst extends StatefulWidget {
  const RingBurst({super.key});

  @override
  State<RingBurst> createState() => _RingBurstState();
}

class _RingBurstState extends State<RingBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(29);
    _sparks = List.generate(28, (i) {
      final angle = (i / 28) * math.pi * 2 + rng.nextDouble() * 0.2;
      return _Spark(
        angle: angle,
        distance: 46 + rng.nextDouble() * 90,
        size: 3.5 + rng.nextDouble() * 4.5,
        color: [
          AppColors.accentSoft,
          AppColors.mint,
          Colors.white,
          AppColors.accent,
        ][i % 4],
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _BurstPainter(progress: _ctrl.value, sparks: _sparks),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _Spark {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final List<_Spark> sparks;

  _BurstPainter({required this.progress, required this.sparks});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (final spark in sparks) {
      final pos = Offset(
        center.dx + math.cos(spark.angle) * spark.distance * t,
        center.dy + math.sin(spark.angle) * spark.distance * t,
      );
      final paint = Paint()
        ..color = spark.color.withOpacity(0.15 + fade * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(pos, spark.size * (1.15 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
