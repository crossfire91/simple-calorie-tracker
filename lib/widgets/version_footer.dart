import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/update/update_config.dart';

class VersionFooter extends StatelessWidget {
  final UpdateStatus? status;
  final VoidCallback? onTap;

  const VersionFooter({
    super.key,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = status?.installed.versionName.trim().isNotEmpty == true
        ? status!.installed.versionName
        : UpdateConfig.fallbackVersionName;
    final hasUpdate = status?.hasUpdate == true;
    final label = hasUpdate
        ? s.versionUpdate(version, status!.newer!.versionName)
        : status?.isCurrent == true
            ? s.versionCurrent(version)
            : s.versionOnly(version);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hasUpdate ? onTap : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: hasUpdate ? AppColors.mint.withOpacity(0.85) : AppColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
