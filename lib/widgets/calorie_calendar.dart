import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/habit/streak.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class CalorieCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final int kcalBudget;
  final Map<String, DayDigest> digests;
  final ValueChanged<DateTime> onDateSelected;

  const CalorieCalendar({
    super.key,
    required this.selectedDate,
    required this.kcalBudget,
    required this.digests,
    required this.onDateSelected,
  });

  @override
  State<CalorieCalendar> createState() => _CalorieCalendarState();
}

class _CalorieCalendarState extends State<CalorieCalendar> {
  static const _weeksBack = 104;
  static const _weeksForward = 8;

  late final DateTime _firstMonday;
  late final int _pageCount;
  late final PageController _weekController;
  late DateTime _monthCursor;
  late int _visibleWeekIndex;
  bool _monthOpen = false;

  DateTime get _today => JourneyMath.dayOnly(DateTime.now());
  DateTime get _selected => JourneyMath.dayOnly(widget.selectedDate);

  @override
  void initState() {
    super.initState();
    _firstMonday = JourneyMath.mondayOf(_today)
        .subtract(const Duration(days: 7 * _weeksBack));
    _pageCount = _weeksBack + _weeksForward + 1;
    _visibleWeekIndex = _weekIndex(_selected).clamp(0, _pageCount - 1);
    _weekController = PageController(initialPage: _visibleWeekIndex);
    _monthCursor = DateTime(_selected.year, _selected.month);
  }

  @override
  void didUpdateWidget(CalorieCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!JourneyMath.sameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _monthCursor = DateTime(_selected.year, _selected.month);
      final idx = _weekIndex(_selected).clamp(0, _pageCount - 1);
      if (_weekController.hasClients &&
          _weekController.page?.round() != idx) {
        _weekController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  int _weekIndex(DateTime date) =>
      JourneyMath.mondayOf(date).difference(_firstMonday).inDays ~/ 7;

  DateTime _mondayAt(int index) =>
      _firstMonday.add(Duration(days: index * 7));

  DayDigest? _digestFor(DateTime date) =>
      widget.digests[JourneyMath.dateKey(date)];

  Set<String> get _streakKeys =>
      StreakMath.currentStreakKeys(StreakMath.mealKeys(widget.digests));

  void _select(DateTime date) {
    HapticFeedback.selectionClick();
    widget.onDateSelected(JourneyMath.dayOnly(date));
  }

  void _goToday() {
    _select(_today);
    setState(() {
      _monthCursor = DateTime(_today.year, _today.month);
      _monthOpen = false;
    });
  }

  void _shiftWeek(int delta) {
    final next = (_visibleWeekIndex + delta).clamp(0, _pageCount - 1);
    _weekController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _monthCursor = DateTime(_monthCursor.year, _monthCursor.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final visibleMonday = _mondayAt(_visibleWeekIndex);
    final headerDate = _monthOpen ? _monthCursor : visibleMonday;
    final isThisWeek = JourneyMath.sameDay(visibleMonday, JourneyMath.mondayOf(_today));
    final showToday = !JourneyMath.sameDay(_selected, _today);
    final streakKeys = _streakKeys;
    final streak = streakKeys.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            title: s.monthYear(headerDate),
            subtitle: _subtitle(s, visibleMonday, isThisWeek, streak, streakKeys),
            showToday: showToday,
            monthOpen: _monthOpen,
            streak: streak,
            streakLabel: s.streakLabel(streak),
            streakChip: s.streakChip(streak),
            onToday: _goToday,
            onStreak: _goToday,
            onPrev: () => _monthOpen ? _shiftMonth(-1) : _shiftWeek(-1),
            onNext: () => _monthOpen ? _shiftMonth(1) : _shiftWeek(1),
            onToggleMonth: () => setState(() => _monthOpen = !_monthOpen),
            prevLabel: _monthOpen ? s.previousMonth : s.previousWeek,
            nextLabel: _monthOpen ? s.nextMonth : s.nextWeek,
            toggleLabel: _monthOpen ? s.hideMonth : s.showMonth,
            todayLabel: s.today,
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _monthOpen
                ? _MonthGrid(
                    month: _monthCursor,
                    selected: _selected,
                    today: _today,
                    budget: widget.kcalBudget,
                    digestFor: _digestFor,
                    streakKeys: streakKeys,
                    onSelect: _select,
                  )
                : SizedBox(
                    height: 96,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: PageView.builder(
                          controller: _weekController,
                          itemCount: _pageCount,
                          onPageChanged: (index) {
                            setState(() => _visibleWeekIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return _WeekStrip(
                              monday: _mondayAt(index),
                              selected: _selected,
                              today: _today,
                              budget: widget.kcalBudget,
                              digestFor: _digestFor,
                              streakKeys: streakKeys,
                              onSelect: _select,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          _SelectedCaption(
            date: _selected,
            digest: _digestFor(_selected),
            budget: widget.kcalBudget,
            streak: streakKeys.contains(JourneyMath.dateKey(_selected))
                ? streak
                : 0,
          ),
        ],
      ),
    );
  }

  String _subtitle(
    S s,
    DateTime monday,
    bool isThisWeek,
    int streak,
    Set<String> streakKeys,
  ) {
    final week = isThisWeek ? s.thisWeek : s.weekLabel(JourneyMath.isoWeek(monday));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    var logged = 0;
    var kcalSum = 0.0;
    var mealDays = 0;
    for (final day in days) {
      final digest = _digestFor(day);
      if (digest == null) continue;
      if (digest.isLogged) logged++;
      if (digest.hasMeals) {
        kcalSum += digest.kcal;
        mealDays++;
      }
    }
    if (logged == 0) return '$week · ${s.emptyWeek}';
    final parts = <String>[week, s.daysOfSeven(logged)];
    if (mealDays > 0) {
      parts.add(s.avgKcal((kcalSum / mealDays).round()));
    }
    final weekHasStreak = days.any((day) => streakKeys.contains(JourneyMath.dateKey(day)));
    if (weekHasStreak && streak > 0) {
      parts.add(s.streakLabel(streak));
    }
    return parts.join(' · ');
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showToday;
  final bool monthOpen;
  final int streak;
  final String streakLabel;
  final String streakChip;
  final VoidCallback onToday;
  final VoidCallback onStreak;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleMonth;
  final String prevLabel;
  final String nextLabel;
  final String toggleLabel;
  final String todayLabel;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.showToday,
    required this.monthOpen,
    required this.streak,
    required this.streakLabel,
    required this.streakChip,
    required this.onToday,
    required this.onStreak,
    required this.onPrev,
    required this.onNext,
    required this.onToggleMonth,
    required this.prevLabel,
    required this.nextLabel,
    required this.toggleLabel,
    required this.todayLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _NavButton(icon: Icons.chevron_left_rounded, label: prevLabel, onTap: onPrev),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: onToggleMonth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: monthOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                          semanticLabel: toggleLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(width: 6),
            _StreakChip(label: streakLabel, chip: streakChip, onTap: onStreak),
          ],
          if (showToday) ...[
            const SizedBox(width: 6),
            _TodayChip(label: todayLabel, onTap: onToday),
          ],
          const SizedBox(width: 4),
          _NavButton(icon: Icons.chevron_right_rounded, label: nextLabel, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Icon(icon, size: 20, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final String label;
  final String chip;
  final VoidCallback onTap;

  const _StreakChip({
    required this.label,
    required this.chip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: const Key('calendar-streak'),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: AppColors.mint.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.mint.withOpacity(0.55)),
            boxShadow: AppColors.glow(AppColors.mint, 0.16),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 15,
                color: AppColors.mint,
              ),
              const SizedBox(width: 4),
              Text(
                chip,
                style: const TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TodayChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppColors.glow(AppColors.accent, 0.18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SelectedCaption extends StatelessWidget {
  final DateTime date;
  final DayDigest? digest;
  final int budget;
  final int streak;

  const _SelectedCaption({
    required this.date,
    required this.digest,
    required this.budget,
    this.streak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    var text = digest == null || !digest!.isLogged
        ? s.dayEmpty
        : s.dayDigestLine(
            kcal: digest!.kcal.round(),
            budget: budget,
            meals: digest!.mealCount,
            weighed: digest!.hasWeight,
          );
    if (streak > 0) {
      text = '$text · ${s.streakLabel(streak)}';
    }
    final over = digest != null && digest!.hasMeals && digest!.kcal > budget;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: over ? AppColors.coralSoft : AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime monday;
  final DateTime selected;
  final DateTime today;
  final int budget;
  final DayDigest? Function(DateTime date) digestFor;
  final Set<String> streakKeys;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({
    required this.monday,
    required this.selected,
    required this.today,
    required this.budget,
    required this.digestFor,
    required this.streakKeys,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final flags = List<bool>.generate(
      7,
      (i) => _onStreak(monday.add(Duration(days: i)), streakKeys),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        _StreakRail(flags: flags),
        Row(
          children: List.generate(7, (i) {
            final date = monday.add(Duration(days: i));
            return Expanded(
              child: _DayCell(
                date: date,
                selected: JourneyMath.sameDay(date, selected),
                isToday: JourneyMath.sameDay(date, today),
                inMonth: true,
                compact: false,
                digest: digestFor(date),
                budget: budget,
                inStreak: flags[i],
                streakLeft: _joinsPrev(date, streakKeys),
                streakRight: _joinsNext(date, streakKeys),
                onTap: () => onSelect(date),
              ),
            );
          }),
        ),
      ],
    );
  }
}

bool _onStreak(DateTime date, Set<String> keys) =>
    keys.contains(JourneyMath.dateKey(date));

bool _joinsPrev(DateTime date, Set<String> keys) =>
    _onStreak(date, keys) &&
    _onStreak(date.subtract(const Duration(days: 1)), keys);

bool _joinsNext(DateTime date, Set<String> keys) =>
    _onStreak(date, keys) &&
    _onStreak(date.add(const Duration(days: 1)), keys);

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final int budget;
  final DayDigest? Function(DateTime date) digestFor;
  final Set<String> streakKeys;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.budget,
    required this.digestFor,
    required this.streakKeys,
    required this.onSelect,
  });

  List<DateTime> _cells() {
    final first = DateTime(month.year, month.month, 1);
    final start = JourneyMath.mondayOf(first);
    final last = DateTime(month.year, month.month + 1, 0);
    final end = JourneyMath.mondayOf(last).add(const Duration(days: 6));
    final count = end.difference(start).inDays + 1;
    return List.generate(count, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cells = _cells();
    return Column(
      children: [
        Row(
          children: List.generate(7, (i) {
            return Expanded(
              child: Text(
                s.weekdaysShort[i],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        ...List.generate((cells.length / 7).ceil(), (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (col) {
                final index = row * 7 + col;
                if (index >= cells.length) {
                  return const Expanded(child: SizedBox(height: 44));
                }
                final date = cells[index];
                return Expanded(
                  child: _DayCell(
                    date: date,
                    selected: JourneyMath.sameDay(date, selected),
                    isToday: JourneyMath.sameDay(date, today),
                    inMonth: date.month == month.month,
                    compact: true,
                    digest: digestFor(date),
                    budget: budget,
                    inStreak: _onStreak(date, streakKeys),
                    streakLeft: _joinsPrev(date, streakKeys),
                    streakRight: _joinsNext(date, streakKeys),
                    onTap: () => onSelect(date),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

class _DayCell extends StatefulWidget {
  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool inMonth;
  final bool compact;
  final DayDigest? digest;
  final int budget;
  final bool inStreak;
  final bool streakLeft;
  final bool streakRight;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.inMonth,
    required this.compact,
    required this.digest,
    required this.budget,
    required this.inStreak,
    required this.streakLeft,
    required this.streakRight,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final digest = widget.digest;
    final hasMeals = digest?.hasMeals ?? false;
    final over = hasMeals && digest!.kcal > widget.budget;
    final progress = !hasMeals || widget.budget <= 0
        ? 0.0
        : (digest!.kcal / widget.budget).clamp(0.0, 1.2);
    final future = widget.date.isAfter(JourneyMath.dayOnly(DateTime.now()));
    final dimmed = !widget.inMonth || future;
    final weekday = s.weekdaysShort[widget.date.weekday - 1];
    final size = widget.compact ? 40.0 : 48.0;

    final fillSelected = widget.selected && !hasMeals;
    Color numberColor;
    if (fillSelected) {
      numberColor = Colors.white;
    } else if (widget.selected || widget.isToday) {
      numberColor = AppColors.accentSoft;
    } else if (dimmed) {
      numberColor = AppColors.textFaint.withOpacity(0.55);
    } else {
      numberColor = AppColors.text;
    }

    return Semantics(
      button: true,
      selected: widget.selected,
      label: s.calendarDayLabel(
        widget.date,
        kcal: hasMeals ? digest!.kcal.round() : null,
        meals: digest?.mealCount ?? 0,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (!widget.compact) ...[
                Text(
                  weekday,
                  style: TextStyle(
                    color: widget.isToday
                        ? AppColors.accentSoft
                        : widget.selected
                            ? Colors.white
                            : widget.inStreak
                                ? AppColors.mint
                                : AppColors.textFaint,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: fillSelected ? AppColors.gradient : null,
                        color: fillSelected
                            ? null
                            : widget.isToday || widget.selected
                                ? AppColors.surfaceHigh
                                : Colors.transparent,
                        border: Border.all(
                          color: fillSelected
                              ? Colors.white.withOpacity(0.18)
                              : widget.isToday
                                  ? AppColors.accentSoft.withOpacity(widget.selected ? 0.95 : 0.82)
                                  : widget.selected
                                      ? Colors.transparent
                                      : widget.inStreak
                                          ? AppColors.mint.withOpacity(0.42)
                                          : Colors.transparent,
                          width: widget.isToday
                              ? 2
                              : (widget.inStreak && !widget.selected)
                                  ? 1.4
                                  : 1,
                        ),
                        boxShadow: widget.isToday
                            ? AppColors.glow(
                                AppColors.accent,
                                widget.selected ? 0.34 : 0.22,
                              )
                            : widget.selected
                                ? AppColors.glow(
                                    over ? AppColors.coral : AppColors.accent,
                                    hasMeals ? 0.32 : 0.28,
                                  )
                                : widget.inStreak
                                    ? AppColors.glow(AppColors.mint, 0.1)
                                    : null,
                      ),
                    ),
                    if (hasMeals)
                      CustomPaint(
                        size: Size(size, size),
                        painter: _MiniRingPainter(
                          progress: progress.clamp(0.0, 1.0),
                          over: over,
                          selected: widget.selected,
                          today: widget.isToday,
                        ),
                      ),
                    Text(
                      '${widget.date.day}',
                      style: TextStyle(
                        color: numberColor,
                        fontWeight: FontWeight.w700,
                        fontSize: widget.compact ? 12 : 14,
                        height: 1,
                      ),
                    ),
                    if (digest?.hasWeight == true || (widget.isToday && hasMeals))
                      Positioned(
                        bottom: widget.compact ? 4 : 5,
                        child: _TrackedPip(
                          today: widget.isToday,
                          selected: widget.selected,
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.compact)
                SizedBox(
                  height: 8,
                  width: double.infinity,
                  child: _StreakLink(
                    active: widget.inStreak,
                    left: widget.streakLeft,
                    right: widget.streakRight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackedPip extends StatelessWidget {
  final bool today;
  final bool selected;

  const _TrackedPip({required this.today, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = today
        ? AppColors.accentSoft
        : selected
            ? Colors.white
            : AppColors.mint;
    return Container(
      width: today ? 6 : 5,
      height: today ? 6 : 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: today
            ? [
                BoxShadow(
                  color: AppColors.accentSoft.withOpacity(0.85),
                  blurRadius: 8,
                  spreadRadius: 1.6,
                ),
                BoxShadow(
                  color: AppColors.accentSoft.withOpacity(0.45),
                  blurRadius: 14,
                  spreadRadius: 2.4,
                ),
              ]
            : null,
      ),
    );
  }
}

class _StreakRail extends StatelessWidget {
  final List<bool> flags;

  const _StreakRail({required this.flags});

  @override
  Widget build(BuildContext context) {
    int? start;
    int? end;
    for (var i = 0; i < flags.length; i++) {
      if (!flags[i]) continue;
      start ??= i;
      end = i;
    }
    if (start == null || end == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / 7;
        return Stack(
          children: [
            Positioned(
              left: start! * cell + 3,
              width: (end! - start! + 1) * cell - 6,
              top: 24,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.mint.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.mint.withOpacity(0.5),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StreakLink extends StatelessWidget {
  final bool active;
  final bool left;
  final bool right;

  const _StreakLink({
    required this.active,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();

    if (!left && !right) {
      return Center(
        child: Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: left ? _bar() : const SizedBox.shrink()),
        Expanded(child: right ? _bar() : const SizedBox.shrink()),
      ],
    );
  }

  Widget _bar() {
    return Container(
      height: 3,
      color: AppColors.mint.withOpacity(0.85),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final bool over;
  final bool selected;
  final bool today;

  _MiniRingPainter({
    required this.progress,
    required this.over,
    this.selected = false,
    this.today = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final marked = selected || today;
    final radius = size.width / 2 - (marked ? 5.2 : 3.5);
    final stroke = marked ? 3.4 : 2.6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final hue = over ? AppColors.coralSoft : AppColors.accentSoft;

    if (today) {
      final todayHalo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.4 : 2
        ..color = AppColors.accentSoft.withOpacity(selected ? 1 : 0.88);
      canvas.drawCircle(center, size.width / 2 - 1.3, todayHalo);
    } else if (selected) {
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = hue.withOpacity(0.95);
      canvas.drawCircle(center, size.width / 2 - 1.3, halo);
    }

    if (progress > 0) {
      final pie = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius - stroke * 0.35), -math.pi / 2, math.pi * 2 * progress, false)
        ..close();
      canvas.drawPath(
        pie,
        Paint()
          ..style = PaintingStyle.fill
          ..color = hue.withOpacity(selected ? 0.34 : today ? 0.24 : 0.16),
      );
    }

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = marked ? const Color(0xFF31415A) : const Color(0xFF243044);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final colors = over
        ? const [AppColors.coralSoft, AppColors.rose]
        : const [AppColors.accentSoft, AppColors.mint];

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: colors,
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, sweep);
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.over != over ||
        oldDelegate.selected != selected ||
        oldDelegate.today != today;
  }
}
