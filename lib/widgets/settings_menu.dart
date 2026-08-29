import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/update/update_config.dart';

enum _SettingsAction { language, backup, keys, version }

class SettingsMenuButton extends StatelessWidget {
  final VoidCallback onBackup;
  final VoidCallback onApiKeys;
  final VoidCallback onCheckUpdate;
  final UpdateStatus? updateStatus;

  const SettingsMenuButton({
    super.key,
    required this.onBackup,
    required this.onApiKeys,
    required this.onCheckUpdate,
    this.updateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopupMenuButton<_SettingsAction>(
      tooltip: s.settings,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 8),
      elevation: 12,
      color: AppColors.surfaceHigh,
      shadowColor: Colors.black.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.stroke),
      ),
      onSelected: (action) {
        switch (action) {
          case _SettingsAction.language:
            LocaleScope.of(context).toggle();
          case _SettingsAction.backup:
            onBackup();
          case _SettingsAction.keys:
            onApiKeys();
          case _SettingsAction.version:
            onCheckUpdate();
        }
      },
      itemBuilder: (context) {
        final menu = S.of(context);
        final hasUpdate = updateStatus?.hasUpdate == true;
        return [
          PopupMenuItem(
            value: _SettingsAction.language,
            child: _SettingsRow(
              icon: Icons.swap_horiz_rounded,
              label: menu.language,
              detail: '${menu.languageShort} → ${menu.languageOtherShort}',
            ),
          ),
          PopupMenuItem(
            value: _SettingsAction.backup,
            child: _SettingsRow(
              icon: Icons.cloud_outlined,
              label: menu.backupTitle,
            ),
          ),
          PopupMenuItem(
            value: _SettingsAction.keys,
            child: _SettingsRow(
              icon: Icons.key_rounded,
              label: menu.apiKeys,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _SettingsAction.version,
            child: _SettingsRow(
              icon: hasUpdate
                  ? Icons.system_update_rounded
                  : Icons.info_outline_rounded,
              label: _versionLabel(menu),
              detail: hasUpdate ? null : menu.checkForUpdate,
              accent: hasUpdate,
            ),
          ),
        ];
      },
      child: Semantics(
        button: true,
        label: s.settings,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.stroke),
          ),
          child: const Icon(Icons.menu_rounded, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }

  String _versionLabel(S s) {
    final version = updateStatus?.installed.versionName.trim().isNotEmpty == true
        ? updateStatus!.installed.versionName
        : UpdateConfig.fallbackVersionName;
    if (updateStatus?.hasUpdate == true) {
      return s.versionUpdate(version, updateStatus!.newer!.versionName);
    }
    if (updateStatus?.isCurrent == true) {
      return s.versionCurrent(version);
    }
    return s.versionOnly(version);
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final bool accent;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.detail,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.mint : AppColors.textMuted;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: accent ? AppColors.mint : AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        if (detail != null)
          Text(
            detail!,
            style: const TextStyle(
              color: AppColors.textFaint,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
