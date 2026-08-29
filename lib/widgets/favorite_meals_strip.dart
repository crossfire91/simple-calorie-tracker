import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class FavoriteMealsStrip extends StatelessWidget {
  final List<FavoriteMeal> favorites;
  final ValueChanged<FavoriteMeal> onLog;
  final ValueChanged<FavoriteMeal> onRemove;

  const FavoriteMealsStrip({
    super.key,
    required this.favorites,
    required this.onLog,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox.shrink();
    final s = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.yourMoves, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text(
              s.tapToLog,
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final fav = favorites[index];
              return _FavoriteTile(
                meal: fav,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onLog(fav);
                },
                onLongPress: () => onRemove(fav),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FavoriteTile extends StatefulWidget {
  final FavoriteMeal meal;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FavoriteTile({
    required this.meal,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<_FavoriteTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 132,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.glow(AppColors.accent, 0.22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.meal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.meal.kcal} kcal',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
