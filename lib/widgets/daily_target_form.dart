import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_text_field.dart';

class DailyTargetForm extends StatefulWidget {
  final DailyTargetProfile initial;
  final bool firstRun;
  final void Function(int kcal, DailyTargetProfile profile) onSave;

  const DailyTargetForm({
    super.key,
    required this.initial,
    required this.onSave,
    this.firstRun = false,
  });

  @override
  State<DailyTargetForm> createState() => _DailyTargetFormState();
}

class _DailyTargetFormState extends State<DailyTargetForm> {
  late DailyTargetProfile profile;
  late final TextEditingController manualController;
  bool _pickedGoal = false;
  bool _pickedSex = false;

  static const _activityIcons = [
    Icons.weekend_rounded,
    Icons.directions_walk_rounded,
    Icons.directions_run_rounded,
    Icons.fitness_center_rounded,
    Icons.local_fire_department_rounded,
  ];

  @override
  void initState() {
    super.initState();
    profile = widget.initial.copy();
    profile.age ??= 28;
    profile.heightCm ??= 170;
    profile.weightKg ??= 72;
    profile.manualKcal ??= 2200;
    if (!widget.firstRun && widget.initial.sex != null && widget.initial.age != null) {
      _pickedGoal = true;
      _pickedSex = true;
    }
    manualController = TextEditingController(
      text: profile.manualKcal.toString(),
    );
  }

  bool get _calculateReady => _pickedGoal && _pickedSex;

  @override
  void dispose() {
    manualController.dispose();
    super.dispose();
  }

  DailyTargetResult? get result {
    if (profile.mode == TargetMode.manual) {
      profile.manualKcal ??= 2200;
    }
    return DailyTargetMath.tryCalculate(profile);
  }

  double get _manualSlider {
    final kcal = profile.manualKcal ?? 2200;
    return kcal.clamp(800, 4500).toDouble();
  }

  void _enterManual() {
    setState(() {
      profile.mode = TargetMode.manual;
      profile.manualKcal = profile.manualKcal ?? 2200;
      manualController.text = '${profile.manualKcal}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final calculated = profile.mode == TargetMode.calculated;
    final lose = profile.goal == GoalType.lose;
    final gain = profile.goal == GoalType.gain;
    final preview = result;
    final activityIndex = ActivityLevel.values.indexOf(profile.activity);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.accentSoft,
        inactiveTrackColor: const Color(0xFF243044),
        thumbColor: Colors.white,
        overlayColor: AppColors.accentSoft.withOpacity(0.16),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTickMarkColor: Colors.white54,
        inactiveTickMarkColor: Colors.white24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Segmented(
            leftSelected: calculated,
            onLeft: () => setState(() => profile.mode = TargetMode.calculated),
            onRight: _enterManual,
          ),
          const SizedBox(height: 16),
          if (!calculated) ...[
            _SliderCard(
              key: const ValueKey('manual-kcal'),
              icon: Icons.bolt_rounded,
              label: s.yourNumber,
              suffix: 'kcal',
              min: 800,
              max: 4500,
              current: _manualSlider,
              divisions: 74,
              textController: manualController,
              onChanged: (v) {
                setState(() {
                  profile.manualKcal = v.round();
                  if (manualController.text != v.round().toString()) {
                    manualController.text = v.round().toString();
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: manualController,
              label: 'Or type it',
              hint: 'e.g. 2200',
              icon: Icons.edit_rounded,
              onChanged: (text) {
                final parsed = int.tryParse(text.trim());
                if (parsed == null) return;
                setState(() => profile.manualKcal = parsed.clamp(800, 4500));
              },
            ),
          ] else ...[
            _Label(s.aimingFor),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _IconChoice(
                    icon: Icons.trending_down_rounded,
                    label: s.lose,
                    subtitle: s.loseHint,
                    selected: _pickedGoal && profile.goal == GoalType.lose,
                    onTap: () => setState(() {
                      profile.goal = GoalType.lose;
                      profile.paceKgPerWeek = 0.5;
                      _pickedGoal = true;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _IconChoice(
                    icon: Icons.favorite_rounded,
                    label: s.keep,
                    subtitle: s.keepHint,
                    selected: _pickedGoal && profile.goal == GoalType.maintain,
                    onTap: () => setState(() {
                      profile.goal = GoalType.maintain;
                      _pickedGoal = true;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _IconChoice(
                    icon: Icons.trending_up_rounded,
                    label: s.gain,
                    subtitle: s.gainHint,
                    selected: _pickedGoal && profile.goal == GoalType.gain,
                    onTap: () => setState(() {
                      profile.goal = GoalType.gain;
                      profile.paceKgPerWeek = 0.25;
                      _pickedGoal = true;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LockedStep(
              unlocked: _pickedGoal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label(s.sexHeading),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _IconChoice(
                          icon: Icons.woman_rounded,
                          label: s.woman,
                          selected: _pickedSex && profile.sex == BiologicalSex.female,
                          onTap: () => setState(() {
                            profile.sex = BiologicalSex.female;
                            _pickedSex = true;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _IconChoice(
                          icon: Icons.man_rounded,
                          label: s.man,
                          selected: _pickedSex && profile.sex == BiologicalSex.male,
                          onTap: () => setState(() {
                            profile.sex = BiologicalSex.male;
                            _pickedSex = true;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _IconChoice(
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          label: s.skip,
                          selected: _pickedSex && profile.sex == BiologicalSex.unspecified,
                          onTap: () => setState(() {
                            profile.sex = BiologicalSex.unspecified;
                            _pickedSex = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _LockedStep(
              unlocked: _pickedSex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SliderCard(
                    icon: Icons.cake_rounded,
                    label: s.age,
                    suffix: s.years,
                    min: DailyTargetMath.minAge.toDouble(),
                    max: DailyTargetMath.maxAge.toDouble(),
                    current: (profile.age ?? 28).toDouble(),
                    divisions: DailyTargetMath.maxAge - DailyTargetMath.minAge,
                    onChanged: (v) => setState(() {
                      profile.age = v.round();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _SliderCard(
                    icon: Icons.height_rounded,
                    label: s.height,
                    suffix: 'cm',
                    min: 140,
                    max: 210,
                    current: (profile.heightCm ?? 170).clamp(140, 210),
                    divisions: 70,
                    onChanged: (v) => setState(() {
                      profile.heightCm = v.roundToDouble();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _SliderCard(
                    icon: Icons.monitor_weight_rounded,
                    label: s.weight,
                    suffix: 'kg',
                    decimals: 1,
                    min: 40,
                    max: 180,
                    current: (profile.weightKg ?? 72).clamp(40, 180),
                    divisions: 140,
                    onChanged: (v) => setState(() {
                      profile.weightKg = (v * 10).round() / 10;
                    }),
                  ),
                  const SizedBox(height: 10),
                  _SliderCard(
                    icon: _activityIcons[activityIndex],
                    label: s.aNormalWeek,
                    display: s.activityLabels[activityIndex],
                    editable: false,
                    min: 0,
                    max: 4,
                    current: activityIndex.toDouble(),
                    divisions: 4,
                    onChanged: (v) => setState(() {
                      profile.activity = ActivityLevel.values[v.round().clamp(0, 4)];
                    }),
                  ),
                  if (lose || gain) ...[
                    const SizedBox(height: 10),
                    _SliderCard(
                      icon: lose ? Icons.speed_rounded : Icons.restaurant_rounded,
                      label: lose ? s.howQuickly : s.howYouGrow,
                      suffix: 'kg/wk',
                      hint: s.paceName(profile.paceKgPerWeek, lose),
                      decimals: 2,
                      min: lose ? 0.25 : 0.15,
                      max: lose ? 1.0 : 0.5,
                      current: profile.paceKgPerWeek.clamp(lose ? 0.25 : 0.15, lose ? 1.0 : 0.5),
                      divisions: lose ? 15 : 14,
                      onChanged: (v) => setState(() {
                        profile.paceKgPerWeek = (v * 20).round() / 20;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _LockedStep(
            unlocked: !calculated || _calculateReady,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Label(s.yourNumberLabel),
                const SizedBox(height: 10),
                _HeroNumber(
                  result: !calculated || _calculateReady ? preview : null,
                  calculated: calculated,
                  goal: profile.goal,
                  fallbackKcal: calculated ? null : _manualSlider.round(),
                ),
                if (preview?.noteKind != null && (!calculated || _calculateReady)) ...[
                  const SizedBox(height: 12),
                  _NotePill(
                    text: s.targetNote(
                      preview!.noteKind!,
                      preview.plannedKgPerWeek,
                      weightKg: profile.weightKg,
                    ),
                    highlight: preview.wasCapped || preview.underweightBlocked,
                  ),
                ],
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: widget.firstRun ? s.startTracking : s.saveThisNumber,
                  icon: Icons.favorite_rounded,
                  onPressed: preview == null || (calculated && !_calculateReady)
                      ? null
                      : () => widget.onSave(preview.targetKcal, profile),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.estimateDisclaimer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroNumber extends StatelessWidget {
  final DailyTargetResult? result;
  final bool calculated;
  final GoalType goal;
  final int? fallbackKcal;

  const _HeroNumber({
    required this.result,
    required this.calculated,
    required this.goal,
    this.fallbackKcal,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final kcal = result?.targetKcal ?? fallbackKcal;
    final week = result?.plannedKgPerWeek ?? 0;
    String weekLine = s.slideALittle;
    if (kcal != null && !calculated) {
      weekLine = s.yourDayInOneNumber;
    } else if (kcal != null && week == 0) {
      weekLine = s.holdThisBalance;
    } else if (kcal != null) {
      weekLine = s.weekKind(week, gain: goal == GoalType.gain);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2740),
            AppColors.surfaceInput,
          ],
        ),
        border: Border.all(
          color: kcal == null ? AppColors.stroke : AppColors.accentSoft.withOpacity(0.35),
        ),
        boxShadow: kcal == null ? null : AppColors.glow(AppColors.accent, 0.22),
      ),
      child: Column(
        children: [
          Icon(
            kcal == null ? Icons.auto_awesome_outlined : Icons.auto_awesome_rounded,
            color: kcal == null ? AppColors.textFaint : AppColors.accentSoft,
            size: 18,
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              kcal?.toString() ?? '—',
              key: ValueKey(kcal),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40),
            ),
          ),
          const SizedBox(height: 2),
          Text(s.kcalPerDay, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(
            weekLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.accentSoft,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _Segmented({
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegTab(
              icon: Icons.auto_awesome_rounded,
              label: S.of(context).calculate,
              selected: leftSelected,
              onTap: onLeft,
            ),
          ),
          Expanded(
            child: _SegTab(
              icon: Icons.tune_rounded,
              label: S.of(context).enterNumber,
              selected: !leftSelected,
              onTap: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.gradient : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.gradient : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : AppColors.stroke),
          boxShadow: selected ? AppColors.glow(AppColors.accent, 0.22) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.accentSoft, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppColors.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SliderCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? suffix;
  final String? hint;
  final String? display;
  final double min;
  final double max;
  final double current;
  final int decimals;
  final int? divisions;
  final bool editable;
  final TextEditingController? textController;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    super.key,
    required this.icon,
    required this.label,
    required this.min,
    required this.max,
    required this.current,
    required this.onChanged,
    this.suffix,
    this.hint,
    this.display,
    this.decimals = 0,
    this.divisions,
    this.editable = true,
    this.textController,
  });

  @override
  State<_SliderCard> createState() => _SliderCardState();
}

class _SliderCardState extends State<_SliderCard> {
  TextEditingController? _ownedController;
  late final FocusNode _focus;

  TextEditingController get _controller =>
      widget.textController ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.textController == null) {
      _ownedController = TextEditingController(text: _fmt(widget.current));
    } else if (widget.textController!.text.trim().isEmpty) {
      widget.textController!.text = _fmt(widget.current);
    }
    _focus = FocusNode()..addListener(() {
      if (!_focus.hasFocus) _commit(_controller.text, clamp: true);
    });
  }

  @override
  void didUpdateWidget(covariant _SliderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focus.hasFocus) return;
    final next = _fmt(widget.current);
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  String _fmt(double value) {
    if (widget.decimals <= 0) return value.round().toString();
    return value.toStringAsFixed(widget.decimals);
  }

  void _commit(String raw, {required bool clamp}) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null) {
      _controller.text = _fmt(widget.current);
      return;
    }
    final next = clamp ? parsed.clamp(widget.min, widget.max).toDouble() : parsed;
    if (next < widget.min || next > widget.max) return;
    widget.onChanged(next);
    if (clamp) _controller.text = _fmt(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.hint != null)
                      Text(
                        widget.hint!,
                        style: const TextStyle(
                          color: AppColors.accentSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.editable) ...[
                SizedBox(
                  width: widget.decimals > 0 ? 72 : 64,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.decimals > 0,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        widget.decimals > 0 ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
                      ),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    cursorColor: AppColors.accentSoft,
                    onChanged: (text) => _commit(text, clamp: false),
                    onSubmitted: (text) => _commit(text, clamp: true),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      hintText: _fmt(widget.current),
                      hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accentSoft, width: 1.3),
                      ),
                    ),
                  ),
                ),
                if (widget.suffix != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.suffix!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ] else
                Flexible(
                  child: Text(
                    widget.display ?? '',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
            ],
          ),
          Slider(
            min: widget.min,
            max: widget.max,
            value: widget.current.clamp(widget.min, widget.max),
            divisions: widget.divisions,
            onChanged: (value) {
              _focus.unfocus();
              widget.onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _NotePill extends StatelessWidget {
  final String text;
  final bool highlight;

  const _NotePill({required this.text, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: (highlight ? AppColors.mint : AppColors.accentSoft).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (highlight ? AppColors.mint : AppColors.accentSoft).withOpacity(0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            highlight ? Icons.spa_rounded : Icons.menu_book_rounded,
            size: 16,
            color: highlight ? AppColors.mint : AppColors.accentSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: highlight ? AppColors.mint : AppColors.textMuted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
  }
}

class _LockedStep extends StatelessWidget {
  final bool unlocked;
  final Widget child;

  const _LockedStep({required this.unlocked, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: unlocked ? 1 : 0.55,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: unlocked ? 0 : 5,
          sigmaY: unlocked ? 0 : 5,
        ),
        child: IgnorePointer(
          ignoring: !unlocked,
          child: child,
        ),
      ),
    );
  }
}
