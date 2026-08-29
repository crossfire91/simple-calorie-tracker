import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class FavoriteMealsStrip extends StatelessWidget {
  final List<FavoriteMeal> favorites;
  final ValueChanged<FavoriteMeal> onLog;
  final ValueChanged<FavoriteMeal> onRemove;
  final bool hasPinned;
  final Set<String> pinnedIds;

  const FavoriteMealsStrip({
    super.key,
    required this.favorites,
    required this.onLog,
    required this.onRemove,
    this.hasPinned = true,
    this.pinnedIds = const {},
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
            Icon(
              hasPinned ? Icons.bookmark_rounded : Icons.replay_rounded,
              size: 13,
              color: hasPinned ? AppColors.mint : AppColors.textFaint,
            ),
            const SizedBox(width: 6),
            Text(
              hasPinned ? s.yourMoves : s.againThese,
              style: Theme.of(context).textTheme.labelSmall,
            ),
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
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final fav = favorites[index];
              return _FavoriteTile(
                meal: fav,
                pinned: pinnedIds.contains(fav.id),
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
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FavoriteTile({
    required this.meal,
    required this.pinned,
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
    final pinned = widget.pinned;
    final accent = pinned ? AppColors.mint : AppColors.accentSoft;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 148,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pinned ? AppColors.mint.withOpacity(0.28) : AppColors.stroke,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        accent.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            pinned ? Icons.bookmark_rounded : Icons.replay_rounded,
                            size: 13,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            widget.meal.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.2,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${widget.meal.kcal} kcal',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${widget.meal.weightInGrams} g',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
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
