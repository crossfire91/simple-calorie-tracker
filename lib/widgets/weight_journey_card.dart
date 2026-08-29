import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/tracked_days_strip.dart';
import 'package:simple_calorie_tracker/widgets/weight_sparkline.dart';

class WeightJourneyCard extends StatefulWidget {
  final WeightSnapshot snapshot;
  final VoidCallback onLogWeight;
  final Map<String, DayDigest> digests;
  final int kcalBudget;

  const WeightJourneyCard({
    super.key,
    required this.snapshot,
    required this.onLogWeight,
    this.digests = const {},
    this.kcalBudget = 0,
  });

  @override
  State<WeightJourneyCard> createState() => _WeightJourneyCardState();
}

class _WeightJourneyCardState extends State<WeightJourneyCard> {
  static const _prefKey = 'hideJourneyWeight';
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _hidden = prefs.getBool(_prefKey) ?? false);
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    setState(() => _hidden = !_hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _hidden);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final snapshot = widget.snapshot;
    final result = snapshot.result;
    if (result == null && snapshot.profile.mode != TargetMode.manual) {
      return const SizedBox.shrink();
    }

    final plannedKgPerWeek = snapshot.journeyPaceKgPerWeek;
    final start = snapshot.startKg;
    final current = snapshot.currentKg;
    final started = snapshot.startedAt;
    final delta = snapshot.deltaKg;
    final hasHistory = snapshot.logs.isNotEmpty && start != null && current != null;

    final since = started == null ? s.logToBeginLine : s.sinceDate(started);

    String hint = s.firstWeighInHint;
    if (hasHistory && started != null) {
      hint = s.paceHint(
        JourneyMath.paceHint(
          goal: snapshot.journeyGoal,
          startKg: start,
          currentKg: current,
          startDate: started,
          onDate: DateTime.now(),
          plannedKgPerWeek: plannedKgPerWeek,
        ),
      );
    }

    final deltaLabel = delta == 0
        ? '0.0 kg'
        : '${delta > 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)} kg';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(s.yourJourney, style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              _HideChip(hidden: _hidden, onTap: _toggle),
              const SizedBox(width: 8),
              _LogChip(onTap: widget.onLogWeight),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: s.start,
                  value: start == null ? '—' : '${start.toStringAsFixed(1)} kg',
                  blur: _hidden,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: s.now,
                  value: current == null ? '—' : '${current.toStringAsFixed(1)} kg',
                  emphasize: true,
                  blur: _hidden,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: s.change,
                  value: hasHistory ? deltaLabel : '—',
                  color: !hasHistory
                      ? AppColors.text
                      : delta.abs() < 0.15
                          ? AppColors.mint
                          : delta < 0
                              ? AppColors.coralSoft
                              : AppColors.accentSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            since,
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          snapshot.logs.isEmpty
              ? const _EmptyJourney()
              : WeightSparkline(
                  logs: snapshot.logs,
                  goal: snapshot.journeyGoal,
                  plannedKgPerWeek: plannedKgPerWeek,
                ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.accentSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TrackedDaysStrip(
            trackedDateKeys: snapshot.trackedDateKeys,
            digests: widget.digests,
            kcalBudget: widget.kcalBudget,
          ),
        ],
      ),
    );
  }
}

class _BlurIf extends StatelessWidget {
  final bool hide;
  final Widget child;

  const _BlurIf({required this.hide, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!hide) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: IgnorePointer(child: child),
        ),
      ),
    );
  }
}

class _EmptyJourney extends StatelessWidget {
  const _EmptyJourney();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.12),
            AppColors.surfaceHigh,
          ],
        ),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Text(
        S.of(context).lineStartsToday,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final bool blur;
  final Color? color;

  const _Stat({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.blur = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        _BlurIf(
          hide: blur,
          child: Text(
            value,
            style: TextStyle(
              color: color ?? (emphasize ? AppColors.accentSoft : AppColors.text),
              fontSize: emphasize ? 22 : 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _HideChip extends StatelessWidget {
  final bool hidden;
  final VoidCallback onTap;

  const _HideChip({required this.hidden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: hidden ? s.showWeights : s.hideWeights,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Icon(
            hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18,
            color: hidden ? AppColors.accentSoft : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _LogChip extends StatelessWidget {
  final VoidCallback onTap;
  const _LogChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.glow(AppColors.accent, 0.18),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              S.of(context).log,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
