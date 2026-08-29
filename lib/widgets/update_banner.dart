import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';

class UpdateBanner extends StatelessWidget {
  final UpdateRelease release;
  final VoidCallback onUpdate;
  final VoidCallback? onDismiss;

  const UpdateBanner({
    super.key,
    required this.release,
    required this.onUpdate,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mint.withOpacity(0.28)),
        boxShadow: AppColors.glow(AppColors.mint, 0.12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.mint.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.system_update_rounded, color: AppColors.mint, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.updateAvailable,
                  style: const TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.updateAvailableSubtitle(release.versionName),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpdate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.glow(AppColors.accent, 0.22),
              ),
              child: Text(
                s.updateNow,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textFaint),
            ),
        ],
      ),
    );
  }
}

class UpdateSettingsTile extends StatefulWidget {
  const UpdateSettingsTile({super.key});

  @override
  State<UpdateSettingsTile> createState() => _UpdateSettingsTileState();
}

class _UpdateSettingsTileState extends State<UpdateSettingsTile> {
  InstalledVersion? _installed;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    AppUpdate.installed().then((value) {
      if (mounted) setState(() => _installed = value);
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final found = await AppUpdate.check(force: true);
      if (!mounted) return;
      if (found == null) {
        await showAppMessage(
          context: context,
          icon: Icons.check_circle_rounded,
          title: S.of(context).updateUpToDate,
          subtitle: S.of(context).currentVersion(_installed?.versionName ?? ''),
        );
        return;
      }
      await showUpdateDialog(context: context, release: found);
    } catch (_) {
      if (!mounted) return;
      await showAppMessage(
        context: context,
        icon: Icons.error_outline_rounded,
        title: S.of(context).updateFailed,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final version = _installed?.versionName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          version.isEmpty ? s.checkForUpdate : s.currentVersion(version),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 12),
        AppGhostButton(
          label: _checking ? s.updateChecking : s.checkForUpdate,
          onPressed: _checking ? null : _check,
        ),
      ],
    );
  }
}

Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateRelease release,
}) {
  return showAppDialog(
    context: context,
    child: AppDialogCard(
      icon: Icons.system_update_rounded,
      iconColors: const [AppColors.mint, AppColors.accentDeep],
      title: S.of(context).updateAvailable,
      subtitle: S.of(context).updateAvailableSubtitle(release.versionName),
      child: _UpdatePrompt(release: release),
    ),
  );
}

class _UpdatePrompt extends StatefulWidget {
  final UpdateRelease release;

  const _UpdatePrompt({required this.release});

  @override
  State<_UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<_UpdatePrompt> with WidgetsBindingObserver {
  bool _busy = false;
  bool _waitingPermission = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingPermission) {
      _waitingPermission = false;
      _start();
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final allowed = await AppUpdate.canInstallPackages();
      if (!allowed) {
        _waitingPermission = true;
        await AppUpdate.openInstallSettings();
        if (mounted) {
          setState(() {
            _busy = false;
            _error = S.of(context).updateAllowInstall;
          });
        }
        return;
      }
      await AppUpdate.downloadAndInstall(
        widget.release,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context).updateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final notes = widget.release.notes.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notes.isNotEmpty) ...[
          Text(
            notes,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
        ],
        if (_busy) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.mint,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.updateDownloading,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: AppColors.coralSoft, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
        ],
        AppPrimaryButton(
          label: _busy ? s.updateDownloading : s.updateNow,
          icon: Icons.download_rounded,
          onPressed: _busy ? null : _start,
        ),
        const SizedBox(height: 10),
        AppGhostButton(
          label: s.updateLater,
          onPressed: _busy
              ? null
              : () async {
                  await AppUpdate.skip(widget.release);
                  if (context.mounted) Navigator.pop(context);
                },
        ),
      ],
    );
  }
}
