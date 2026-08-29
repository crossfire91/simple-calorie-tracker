import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';

class MealCard extends StatelessWidget {
  final String name;
  final double kcal;
  final int grams;
  final int kcalPer100g;
  final bool hasPhotos;
  final bool pinned;
  final VoidCallback onAddServing;
  final VoidCallback onDelete;
  final VoidCallback? onOpenGallery;
  final VoidCallback? onPin;
  final String? photoPath;
  final Uint8List? photoBytes;

  const MealCard({
    super.key,
    this.name = '',
    required this.kcal,
    required this.grams,
    required this.kcalPer100g,
    required this.hasPhotos,
    this.pinned = false,
    required this.onAddServing,
    required this.onDelete,
    this.onOpenGallery,
    this.onPin,
    this.photoPath,
    this.photoBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.glow(AppColors.accent, 0.22),
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
                Text(
                  name.trim().isEmpty ? S.of(context).unnamedMeal : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
                const SizedBox(height: 3),
                Text(
                  '$grams g  ·  $kcalPer100g / 100g',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
