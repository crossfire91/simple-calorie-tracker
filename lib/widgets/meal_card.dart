import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/habit/ring_slices.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';

class MealCard extends StatelessWidget {
  final String name;
  final double kcal;
  final int grams;
  final int kcalPer100g;
  final int dailyBudget;
  final bool hasPhotos;
  final bool pinned;
  final VoidCallback onAddServing;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onPin;
  final String? photoPath;
  final Uint8List? photoBytes;
  final String? description;
  final Color? swatch;
  final double precedingKcal;
  final DateTime? loggedAt;
  final bool selected;
  final VoidCallback? onSelect;

  const MealCard({
    super.key,
    this.name = '',
    required this.kcal,
    required this.grams,
    required this.kcalPer100g,
    this.dailyBudget = 0,
    required this.hasPhotos,
    this.pinned = false,
    required this.onAddServing,
    required this.onDelete,
    this.onEdit,
    this.onOpenGallery,
    this.onPin,
    this.photoPath,
    this.photoBytes,
    this.description,
    this.swatch,
    this.precedingKcal = 0,
    this.loggedAt,
    this.selected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = swatch ?? AppColors.accentSoft;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selected ? accent.withOpacity(0.55) : AppColors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (selected)
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(99)),
                  boxShadow: [BoxShadow(color: accent.withOpacity(0.45), blurRadius: 8)],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit ?? onSelect,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.glow(swatch ?? AppColors.accent, 0.22),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: MealImage(
                        path: photoPath,
                        bytes: photoBytes,
                        fallback: const Center(
                          child: Icon(Icons.restaurant_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (swatch != null) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: swatch,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: swatch!.withOpacity(0.45),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  name.trim().isEmpty ? S.of(context).unnamedMeal : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (onEdit != null)
                                GestureDetector(
                                  onTap: onEdit,
                                  behavior: HitTestBehavior.opaque,
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.edit_rounded, size: 14, color: AppColors.textFaint),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${kcal.toStringAsFixed(0)} kcal',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (dailyBudget > 0) ...[
                            const SizedBox(height: 7),
                            _GoalHitBar(
                              kcal: kcal,
                              budget: dailyBudget,
                              precedingKcal: precedingKcal,
                              swatch: swatch,
                            ),
                            const SizedBox(height: 6),
                          ] else
                            const SizedBox(height: 3),
                          Text(
                            [
                              if (loggedAt != null) S.of(context).clock(loggedAt!),
                              '$grams g',
                              '$kcalPer100g / 100g',
                            ].join('  ·  '),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onPin != null)
            _IconAction(
              icon: pinned ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: pinned ? AppColors.mint : AppColors.textMuted,
              onTap: onPin,
            ),
          if (hasPhotos)
            _IconAction(
              icon: Icons.photo_library_rounded,
              onTap: onOpenGallery,
            ),
          _IconAction(
            icon: Icons.add_rounded,
            onTap: onAddServing,
          ),
          _IconAction(
            icon: Icons.delete_outline_rounded,
            color: AppColors.rose,
            onTap: onDelete,
          ),
        ],
          ),
          if ((description ?? '').trim().isNotEmpty)
            _HiddenNote(text: description!.trim()),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalHitBar extends StatelessWidget {
  final double kcal;
  final int budget;
  final double precedingKcal;
  final Color? swatch;

  const _GoalHitBar({
    required this.kcal,
    required this.budget,
    required this.precedingKcal,
    this.swatch,
  });

  @override
  Widget build(BuildContext context) {
    final share = budget <= 0 ? 0.0 : kcal / budget;
    final span = GoalHitMath.span(
      precedingKcal: precedingKcal,
      kcal: kcal,
      budget: budget,
    );
    final percent = share <= 0
        ? 0
        : share < 0.01
            ? 1
            : (share * 100).round();
    final base = swatch ?? AppColors.accentSoft;
    final colors = span.overflows
        ? const [AppColors.coralSoft, AppColors.rose]
        : [base, Color.lerp(base, Colors.white, 0.22)!];
    final labelColor = span.overflows ? AppColors.coralSoft : base;

    return Semantics(
      container: true,
      label: S.of(context).mealGoalShare(percent),
      child: Row(
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth * span.width * value)
                            .clamp(0.0, constraints.maxWidth);
                        final drawn = width > 0 && width < 3 ? 3.0 : width;
                        final left = (constraints.maxWidth * span.start)
                            .clamp(0.0, (constraints.maxWidth - drawn).clamp(0.0, constraints.maxWidth));
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF243044)),
                            if (drawn > 0)
                              Positioned(
                                left: left,
                                width: drawn,
                                top: 0,
                                bottom: 0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: colors),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            share > 0 && share < 0.01 ? '<1%' : '$percent%',
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenNote extends StatefulWidget {
  final String text;

  const _HiddenNote({required this.text});

  @override
  State<_HiddenNote> createState() => _HiddenNoteState();
}

class _HiddenNoteState extends State<_HiddenNote> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context).originalNote,
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 4),
              Text(
                widget.text,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _IconAction({
    required this.icon,
    this.onTap,
    this.color = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class MealSortToggle extends StatelessWidget {
  final bool newestFirst;
  final ValueChanged<bool> onChanged;

  const MealSortToggle({
    super.key,
    required this.newestFirst,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortOption(
            label: s.newestFirst,
            semanticLabel: s.newestMealsFirst,
            selected: newestFirst,
            onTap: () => onChanged(true),
          ),
          _SortOption(
            label: s.oldestFirst,
            semanticLabel: s.oldestMealsFirst,
            selected: !newestFirst,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.strokeStrong : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accentSoft : AppColors.textFaint,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class MealsEmptyState extends StatelessWidget {
  const MealsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.stroke),
              ),
              child: const Icon(Icons.nightlight_round, color: AppColors.accentSoft, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context).nothingLogged,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              S.of(context).tapPlus,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
