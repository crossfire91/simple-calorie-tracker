import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
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
            subtitle: _subtitle(s, visibleMonday, isThisWeek),
            showToday: showToday,
            monthOpen: _monthOpen,
            onToday: _goToday,
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
                            final monday = _mondayAt(index);
                            return Row(
                              children: List.generate(7, (i) {
                                final date = monday.add(Duration(days: i));
                                return Expanded(
                                  child: _DayCell(
                                    date: date,
                                    selected: JourneyMath.sameDay(date, _selected),
                                    isToday: JourneyMath.sameDay(date, _today),
                                    inMonth: true,
                                    compact: false,
                                    digest: _digestFor(date),
                                    budget: widget.kcalBudget,
                                    onTap: () => _select(date),
                                  ),
                                );
                              }),
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
          ),
        ],
      ),
    );
  }

  String _subtitle(S s, DateTime monday, bool isThisWeek) {
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
    return parts.join(' · ');
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showToday;
  final bool monthOpen;
  final VoidCallback onToday;
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
    required this.onToday,
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

  const _SelectedCaption({
    required this.date,
    required this.digest,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = digest == null || !digest!.isLogged
        ? s.dayEmpty
        : s.dayDigestLine(
            kcal: digest!.kcal.round(),
            budget: budget,
            meals: digest!.mealCount,
            weighed: digest!.hasWeight,
          );
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

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final int budget;
  final DayDigest? Function(DateTime date) digestFor;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.budget,
    required this.digestFor,
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
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.inMonth,
    required this.compact,
    required this.digest,
    required this.budget,
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

    Color numberColor;
    if (widget.selected) {
      numberColor = Colors.white;
    } else if (widget.isToday) {
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
                    color: widget.selected
                        ? AppColors.accentSoft
                        : widget.isToday
                            ? AppColors.accentSoft.withOpacity(0.85)
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
                        gradient: widget.selected ? AppColors.gradient : null,
                        color: widget.selected
                            ? null
                            : widget.isToday
                                ? AppColors.surfaceHigh
                                : Colors.transparent,
                        border: Border.all(
                          color: widget.selected
                              ? Colors.white.withOpacity(0.18)
                              : widget.isToday
                                  ? AppColors.accentSoft.withOpacity(0.7)
                                  : Colors.transparent,
                          width: widget.isToday && !widget.selected ? 1.4 : 1,
                        ),
                        boxShadow: widget.selected
                            ? AppColors.glow(AppColors.accent, 0.28)
                            : null,
                      ),
                    ),
                    if (hasMeals && !widget.selected)
                      CustomPaint(
                        size: Size(size, size),
                        painter: _MiniRingPainter(
                          progress: progress.clamp(0.0, 1.0),
                          over: over,
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
                    if (digest?.hasWeight == true)
                      Positioned(
                        bottom: widget.compact ? 4 : 5,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: widget.selected
                                ? Colors.white
                                : AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final bool over;

  _MiniRingPainter({required this.progress, required this.over});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3.5;
    const stroke = 2.6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF243044);
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
    return oldDelegate.progress != progress || oldDelegate.over != over;
  }
}
