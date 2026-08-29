import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/habit/ring_slices.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';
import 'package:simple_calorie_tracker/widgets/ring_burst.dart';

class CalorieRing extends StatefulWidget {
  final double consumed;
  final int budget;
  final double ghostConsumed;
  final bool celebrate;
  final List<double> mealKcals;
  final List<RingMeal> meals;
  final int? focus;
  final ValueChanged<int?>? onFocus;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.budget,
    this.ghostConsumed = 0,
    this.celebrate = false,
    this.mealKcals = const [],
    this.meals = const [],
    this.focus,
    this.onFocus,
  });

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _select;
  double _from = 0;
  int? _internal;
  int? _painted;
  bool _panned = false;

  List<double> get _kcals => widget.meals.isNotEmpty
      ? [for (final meal in widget.meals) meal.kcal]
      : widget.mealKcals;

  bool get _controlled => widget.onFocus != null;

  int? get _selected => _controlled ? widget.focus : _internal;

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
    _select = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && mounted) {
          setState(() => _painted = null);
        }
      });
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
    final next = _kcals;
    final prev = oldWidget.meals.isNotEmpty
        ? [for (final meal in oldWidget.meals) meal.kcal]
        : oldWidget.mealKcals;
    if (widget.focus != oldWidget.focus) {
      _animateTo(widget.focus);
    }
    if (_selected == RingHit.leftover && widget.consumed >= widget.budget) {
      _commit(null, animate: false);
    }
    if (_selected != null &&
        _selected! >= 0 &&
        (_selected! >= next.length ||
            next.length != prev.length ||
            (_selected! < prev.length && next[_selected!] != prev[_selected!]))) {
      _commit(null, animate: false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _select.dispose();
    super.dispose();
  }

  void _commit(int? next, {bool animate = true}) {
    if (_controlled) {
      widget.onFocus!(next);
    } else {
      setState(() => _internal = next);
      if (animate) _animateTo(next);
    }
  }

  void _animateTo(int? next) {
    if (next == null) {
      _select.reverse();
      return;
    }
    setState(() => _painted = next);
    _select.forward(from: _select.value > 0.05 ? 0.55 : 0);
  }

  void _choose(int? hit) {
    if (hit == null) return;
    HapticFeedback.selectionClick();
    if (hit == RingHit.center || hit == _selected) {
      _commit(null);
      return;
    }
    _commit(hit);
  }

  void _onTap(Offset local, Size size, List<MealRingSlice> slices, double reveal) {
    _choose(
      MealRingMath.hit(local: local, size: size, slices: slices, reveal: reveal),
    );
  }

  void _onPan(Offset local, Size size, List<MealRingSlice> slices, double reveal) {
    const ring = Size(200, 200);
    final center = Offset(ring.width / 2, ring.height / 2);
    if ((local - center).distance > 110) return;
    final leftoverStart = reveal < 1 ? reveal : 1.0;
    final hit = MealRingMath.atTurn(
      turn: MealRingMath.turnOf(local, ring),
      slices: slices,
      leftoverStart: leftoverStart,
    );
    if (hit == null || hit == _selected) return;
    HapticFeedback.selectionClick();
    _commit(hit);
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
    final slices = MealRingMath.slices(
      mealKcals: _kcals,
      budget: widget.budget,
      consumed: widget.consumed,
    );
    final leftoverOpen = !over && displayProgress < 1;
    final selectedMeal = _selected != null &&
            _selected! >= 0 &&
            _selected! < widget.meals.length
        ? widget.meals[_selected!]
        : null;
    final leftoverFocused = _selected == RingHit.leftover;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: displayProgress),
      duration: const Duration(milliseconds: 980),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return AnimatedBuilder(
          animation: Listenable.merge([_pulse, _select]),
          builder: (context, _) {
            final beat = closed ? 1 + (_pulse.value * 0.035) : 1.0;
            final lift = Curves.easeOutCubic.transform(_select.value);
            return SizedBox(
              width: 208,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: beat,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _panned = false,
                      onTapUp: (details) {
                        if (_panned) return;
                        _onTap(details.localPosition, const Size(200, 200), slices, value);
                      },
                      onPanStart: (details) {
                        final hit = MealRingMath.hit(
                          local: details.localPosition,
                          size: const Size(200, 200),
                          slices: slices,
                          reveal: value,
                        );
                        _panned = hit != null && hit != RingHit.center;
                      },
                      onPanUpdate: (details) {
                        if (!_panned) return;
                        _onPan(details.localPosition, const Size(200, 200), slices, value);
                      },
                      child: CustomPaint(
                        size: const Size(200, 200),
                        painter: _RingPainter(
                          progress: value,
                          ghost: ghostProgress,
                          over: over,
                          closed: closed,
                          slices: slices,
                          selectedIndex: _painted,
                          selection: lift,
                        ),
                      ),
                    ),
                  ),
                  if (widget.celebrate) const Positioned.fill(child: IgnorePointer(child: RingBurst())),
                  IgnorePointer(
                    child: SizedBox(
                      width: 138,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                            child: child,
                          ),
                        ),
                        child: leftoverFocused && leftoverOpen
                            ? _RingLeftoverFocus(
                                key: const ValueKey('leftover'),
                                remaining: remaining,
                                budget: widget.budget,
                              )
                            : selectedMeal == null
                                ? _RingRest(
                                    key: const ValueKey('rest'),
                                    remaining: remaining,
                                    over: over,
                                    closed: closed,
                                    consumed: widget.consumed,
                                    budget: widget.budget,
                                    ghostConsumed: widget.ghostConsumed,
                                  )
                                : _RingMealFocus(
                                    key: ValueKey('meal-$_selected'),
                                    meal: selectedMeal,
                                    budget: widget.budget,
                                    color: AppColors.mealSwatch(_selected!),
                                  ),
                      ),
                    ),
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

class _RingRest extends StatelessWidget {
  final double remaining;
  final bool over;
  final bool closed;
  final double consumed;
  final int budget;
  final double ghostConsumed;

  const _RingRest({
    super.key,
    required this.remaining,
    required this.over,
    required this.closed,
    required this.consumed,
    required this.budget,
    required this.ghostConsumed,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
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
          '${consumed.toStringAsFixed(0)} / $budget',
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (ghostConsumed > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${s.yesterdayGhost} ${ghostConsumed.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _RingLeftoverFocus extends StatelessWidget {
  final double remaining;
  final int budget;

  const _RingLeftoverFocus({
    super.key,
    required this.remaining,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final share = budget <= 0 ? 0.0 : remaining / budget;
    final percent = share <= 0
        ? 0
        : share < 0.01
            ? 1
            : (share * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.accentSoft.withOpacity(0.7),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.accentSoft.withOpacity(0.4)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              remaining.toStringAsFixed(0),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 38,
                    height: 1,
                    color: AppColors.accentSoft,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 3),
              child: Text(
                'kcal',
                style: TextStyle(
                  color: AppColors.accentSoft.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          s.stillOpen,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.text,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          share > 0 && share < 0.01 ? '<1%' : '$percent%',
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RingMealFocus extends StatelessWidget {
  final RingMeal meal;
  final int budget;
  final Color color;

  const _RingMealFocus({
    super.key,
    required this.meal,
    required this.budget,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = meal.name.trim().isEmpty ? s.unnamedMeal : meal.name.trim();
    final share = budget <= 0 ? 0.0 : meal.kcal / budget;
    final percent = share <= 0
        ? 0
        : share < 0.01
            ? 1
            : (share * 100).round();
    final meta = [
      if (meal.loggedAt != null) s.clock(meal.loggedAt!),
      share > 0 && share < 0.01 ? '<1%' : '$percent%',
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!meal.hasPhoto)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              width: 22,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
              ),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meal.hasPhoto) ...[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.6),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8)],
                ),
                clipBehavior: Clip.antiAlias,
                child: MealImage(
                  path: meal.photoPath,
                  bytes: meal.photoBytes,
                  fallback: Icon(Icons.restaurant_rounded, color: color, size: 13),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              meal.kcal.toStringAsFixed(0),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: meal.hasPhoto ? 32 : 38,
                    height: 1,
                    color: color,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 3),
              child: Text(
                'kcal',
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.text,
                fontSize: 11,
                height: 1.1,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          meta,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double ghost;
  final bool over;
  final bool closed;
  final List<MealRingSlice> slices;
  final int? selectedIndex;
  final double selection;

  static const _trackColor = Color(0xFF243044);

  _RingPainter({
    required this.progress,
    required this.ghost,
    required this.over,
    required this.closed,
    this.slices = const [],
    this.selectedIndex,
    this.selection = 0,
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

    final leftoverOn = selectedIndex == RingHit.leftover;
    final mealOn = selectedIndex != null && selectedIndex! >= 0;
    final baseGlow = over ? AppColors.coral : closed ? AppColors.mint : AppColors.accent;
    final glowColor = leftoverOn
        ? Color.lerp(baseGlow, AppColors.accentSoft, selection)!
        : mealOn
            ? Color.lerp(baseGlow, AppColors.mealSwatch(selectedIndex!), selection)!
            : baseGlow;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = glowColor.withOpacity(closed ? 0.28 : 0.16 + 0.12 * selection)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, glow);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = _trackColor;
    canvas.drawCircle(center, radius, track);

    final trackEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black.withOpacity(0.22);
    canvas.drawCircle(center, radius - stroke / 2 + 1, trackEdge);

    _paintQuarterTicks(canvas: canvas, center: center, radius: radius, strokeWidth: stroke);

    if (slices.isNotEmpty) {
      _paintMealSlices(
        canvas: canvas,
        center: center,
        radius: radius,
        reveal: progress,
        strokeWidth: stroke,
      );
    } else if (progress > 0) {
      final colors = over
          ? const [AppColors.coralSoft, AppColors.rose]
          : closed
              ? const [AppColors.mint, AppColors.accentSoft, AppColors.accent]
              : const [AppColors.accentSoft, AppColors.accent, AppColors.mint];
      _paintSmoothArc(
        canvas: canvas,
        rect: rect,
        center: center,
        radius: radius,
        progress: progress,
        colors: colors,
        strokeWidth: stroke,
      );
    }

    if (leftoverOn && !over && progress < 1) {
      _paintLeftover(
        canvas: canvas,
        center: center,
        radius: radius,
        progress: progress,
        strokeWidth: stroke,
      );
    }
  }

  void _paintLeftover({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double progress,
    required double strokeWidth,
  }) {
    const origin = -math.pi / 2;
    final angle = origin + progress * math.pi * 2;
    final sweep = (1 - progress) * math.pi * 2;
    if (sweep <= 0.02) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentSoft.withOpacity(0.22 + 0.28 * selection);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle,
      sweep,
      false,
      paint,
    );
  }

  void _paintQuarterTicks({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double strokeWidth,
  }) {
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.07);
    for (final at in const [0.25, 0.5, 0.75]) {
      final angle = -math.pi / 2 + at * math.pi * 2;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * (radius - strokeWidth / 2 + 2.5),
        center + dir * (radius + strokeWidth / 2 - 2.5),
        tick,
      );
    }
  }

  void _paintMealSlices({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double reveal,
    required double strokeWidth,
  }) {
    var selectedPos = -1;
    for (var i = 0; i < slices.length; i++) {
      if (slices[i].mealIndex == selectedIndex) {
        selectedPos = i;
        break;
      }
    }

    for (var i = 0; i < slices.length; i++) {
      if (i == selectedPos) continue;
      _paintOneSlice(
        canvas: canvas,
        slice: slices[i],
        center: center,
        radius: radius,
        reveal: reveal,
        strokeWidth: strokeWidth,
        lift: 0,
        dim: selection,
        partAtStart: selectedPos >= 0 && i > selectedPos ? _partPx(i - selectedPos) : 0,
        partAtEnd: selectedPos >= 0 && i < selectedPos ? _partPx(selectedPos - i) : 0,
      );
    }

    if (selectedPos >= 0) {
      // Grows inward: the outer edge has to stay clear of the yesterday ring.
      _paintOneSlice(
        canvas: canvas,
        slice: slices[selectedPos],
        center: center,
        radius: radius - 1.2 * selection,
        reveal: reveal,
        strokeWidth: strokeWidth + 2.6 * selection,
        lift: selection,
        dim: 0,
      );
    }
  }

  /// How far a neighbour steps aside, fading out with distance.
  double _partPx(int distance) => selection * 7 / distance;

  void _paintOneSlice({
    required Canvas canvas,
    required MealRingSlice slice,
    required Offset center,
    required double radius,
    required double reveal,
    required double strokeWidth,
    required double lift,
    required double dim,
    double partAtStart = 0,
    double partAtEnd = 0,
  }) {
    if (slice.start >= reveal) return;
    final visible = math.min(slice.sweep, reveal - slice.start);
    if (visible <= 0.0008) return;

    const origin = -math.pi / 2;
    var angle = origin + slice.start * math.pi * 2;
    var sweep = visible * math.pi * 2;

    final base = Color.lerp(slice.color, _trackColor, dim * 0.62)!;
    final head = Color.lerp(base, Colors.white, 0.26 + 0.16 * lift)!;
    final tail = Color.lerp(base, Colors.black, 0.12)!;

    if (slices.length > 1) {
      // A round cap overhangs its arc by half the stroke, so the trim has to
      // scale with the stroke — otherwise a thicker segment eats the gap.
      const clearPx = 5.0;
      final trimStart = (strokeWidth / 2 + clearPx / 2 + partAtStart) / radius;
      final trimEnd = (strokeWidth / 2 + clearPx / 2 + partAtEnd) / radius;
      final trimmed = sweep - trimStart - trimEnd;
      if (trimmed <= 0) {
        _paintSliceDot(
          canvas: canvas,
          center: center,
          radius: radius,
          angle: angle + sweep / 2,
          slotPx: sweep * radius - clearPx,
          color: base,
          maxSize: strokeWidth,
        );
        return;
      }
      angle += trimStart;
      sweep = trimmed;
    }
    if (sweep <= 0) return;

    if (lift > 0) {
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..color = slice.color.withOpacity(0.3 * lift)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        sweep,
        false,
        halo,
      );
    }

    _paintArcGradient(
      canvas: canvas,
      center: center,
      radius: radius,
      startAngle: angle,
      sweep: sweep,
      from: head,
      to: tail,
      strokeWidth: strokeWidth,
    );

    // Specular highlight: brightest where the segment begins, gone by its end.
    final sheenSteps = math.max(4, (sweep / (math.pi * 2) * 90).round());
    final sheen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, strokeWidth * 0.2)
      ..strokeCap = StrokeCap.round;
    final sheenRect = Rect.fromCircle(center: center, radius: radius + strokeWidth * 0.3);
    final peak = (0.2 + 0.22 * lift) * (1 - dim * 0.8);
    for (var i = 0; i < sheenSteps; i++) {
      final t = i / sheenSteps;
      final fade = (1 - t * 1.7).clamp(0.0, 1.0);
      if (fade <= 0) break;
      sheen.color = Colors.white.withOpacity(peak * fade);
      canvas.drawArc(sheenRect, angle + sweep * t, sweep / sheenSteps, false, sheen);
    }
  }

  /// A meal too small to hold a capsule plus its gaps still gets a mark.
  void _paintSliceDot({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double angle,
    required double slotPx,
    required Color color,
    required double maxSize,
  }) {
    if (slotPx < 2.5) return;
    final size = math.min(maxSize, slotPx);
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(pos, size / 2, Paint()..color = color);
  }

  void _paintArcGradient({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweep,
    required Color from,
    required Color to,
    required double strokeWidth,
  }) {
    // SweepGradient snaps to hard color bands on Flutter web, so the arc is
    // drawn as round-capped steps that overlap into a seamless run.
    final rect = Rect.fromCircle(center: center, radius: radius);
    final steps = math.max(6, (sweep / (math.pi * 2) * 110).round());
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final step = sweep / steps;
    for (var i = 0; i < steps; i++) {
      paint.color = Color.lerp(from, to, i / (steps - 1))!;
      canvas.drawArc(rect, startAngle + step * i, step, false, paint);
    }
  }

  void _paintSmoothArc({
    required Canvas canvas,
    required Rect rect,
    required Offset center,
    required double radius,
    required double progress,
    required List<Color> colors,
    required double strokeWidth,
  }) {
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final segments = math.max(24, (sweep / (math.pi * 2) * 120).round());
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < segments; i++) {
      final t0 = i / segments;
      final startAngle = start + sweep * t0;
      paint.color = _lerpStops(colors, t0 * progress);
      canvas.drawArc(rect, startAngle, sweep / segments + 0.018, false, paint);
    }

    final cap = Paint()..style = PaintingStyle.fill;
    cap.color = colors.first;
    canvas.drawCircle(
      Offset(center.dx + radius * math.cos(start), center.dy + radius * math.sin(start)),
      strokeWidth / 2,
      cap,
    );
    if (progress < 0.995) {
      final end = start + sweep;
      cap.color = _lerpStops(colors, progress);
      canvas.drawCircle(
        Offset(center.dx + radius * math.cos(end), center.dy + radius * math.sin(end)),
        strokeWidth / 2,
        cap,
      );
    }
  }

  Color _lerpStops(List<Color> colors, double t) {
    if (colors.isEmpty) return Colors.transparent;
    if (colors.length == 1 || t <= 0) return colors.first;
    if (t >= 1) return colors.last;
    final scaled = t * (colors.length - 1);
    final index = scaled.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[index], colors[index + 1], scaled - index)!;
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    if (oldDelegate.progress != progress ||
        oldDelegate.ghost != ghost ||
        oldDelegate.over != over ||
        oldDelegate.closed != closed ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.selection != selection ||
        oldDelegate.slices.length != slices.length) {
      return true;
    }
    for (var i = 0; i < slices.length; i++) {
      if (!slices[i].sameAs(oldDelegate.slices[i])) return true;
    }
    return false;
  }
}
