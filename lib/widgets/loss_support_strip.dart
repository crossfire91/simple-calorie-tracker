import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';

class _LossVisual {
  final LossHelper id;
  final IconData icon;
  final List<Color> colors;

  const _LossVisual({
    required this.id,
    required this.icon,
    required this.colors,
  });
}

const _lossVisuals = [
  _LossVisual(
    id: LossHelper.scale,
    icon: Icons.scale_rounded,
    colors: [Color(0xFF7C9CFF), AppColors.accentDeep],
  ),
  _LossVisual(
    id: LossHelper.protein,
    icon: Icons.set_meal_rounded,
    colors: [Color(0xFFFFB086), AppColors.coral],
  ),
  _LossVisual(
    id: LossHelper.water,
    icon: Icons.water_drop_rounded,
    colors: [AppColors.accentSoft, Color(0xFF2A6FDB)],
  ),
  _LossVisual(
    id: LossHelper.volume,
    icon: Icons.eco_rounded,
    colors: [AppColors.mint, Color(0xFF1E8F78)],
  ),
  _LossVisual(
    id: LossHelper.walk,
    icon: Icons.directions_walk_rounded,
    colors: [Color(0xFFB388FF), Color(0xFF6A4CFF)],
  ),
];

class LossSupportStrip extends StatelessWidget {
  const LossSupportStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.gentleHelpers, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          s.gentleHelpersSubtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _lossVisuals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _lossVisuals[index];
              return _ProductCard(
                icon: item.icon,
                colors: item.colors,
                title: s.lossTitle(item.id),
                tag: s.lossTag(item.id),
                onTap: () => showAppMessage(
                  context: context,
                  icon: item.icon,
                  title: s.lossTitle(item.id),
                  subtitle: s.lossWhy(item.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String tag;
  final VoidCallback onTap;

  const _ProductCard({
    required this.icon,
    required this.colors,
    required this.title,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.glow(colors.last, 0.22),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tag,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
