import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/backup/backup_file.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';

class BackupForm extends StatefulWidget {
  final BackupCounts counts;
  final BackupRecord record;
  final Future<BackupSnapshot> Function({required bool includePhotos}) createBackup;
  final Future<void> Function(BackupSnapshot snapshot, int bytes) markSaved;
  final Future<void> Function(BackupSnapshot snapshot) restoreBackup;
  final Future<void> Function(bool includePhotos)? onIncludePhotosChanged;
  final Future<void> Function() onRestored;

  const BackupForm({
    super.key,
    required this.counts,
    required this.record,
    required this.createBackup,
    required this.markSaved,
    required this.restoreBackup,
    required this.onRestored,
    this.onIncludePhotosChanged,
  });

  @override
  State<BackupForm> createState() => _BackupFormState();
}

class _BackupFormState extends State<BackupForm> {
  late bool _includePhotos = widget.record.includePhotos;
  late BackupRecord _record = widget.record;
  bool _busy = false;
  String? _status;

  Future<void> _setIncludePhotos(bool value) async {
    if (_busy || value == _includePhotos) return;
    HapticFeedback.selectionClick();
    setState(() => _includePhotos = value);
    await widget.onIncludePhotosChanged?.call(value);
  }

  Future<void> _backup(BackupDestination destination) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final snapshot = await widget.createBackup(includePhotos: _includePhotos);
      final bytes = snapshot.encodeBytes();
      if (!mounted) return;
      final action = await BackupFile.save(bytes, destination: destination);
      if (!mounted) return;
      if (action.canceled) {
        setState(() => _status = S.of(context).backupCanceled);
        return;
      }
      if (!action.saved) {
        setState(() => _status = S.of(context).backupFailed);
        return;
      }
      await widget.markSaved(snapshot, bytes.length);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _record = _record.copyWith(
          lastAt: snapshot.createdAt,
          lastBytes: bytes.length,
          includePhotos: snapshot.includePhotos,
        );
        _status = null;
      });
      final toDrive = destination == BackupDestination.drive;
      await showAppMessage(
        context: context,
        icon: toDrive ? Icons.cloud_done_rounded : Icons.download_rounded,
        title: toDrive ? S.of(context).backupSavedDrive : S.of(context).backupSaved,
        subtitle: toDrive
            ? S.of(context).backupSavedDriveSubtitle
            : S.of(context).backupSavedSubtitle,
      );
    } catch (_) {
      if (mounted) setState(() => _status = S.of(context).backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(BackupDestination destination) async {
    if (_busy) return;
    final s = S.of(context);
    final fromDrive = destination == BackupDestination.drive;
    final ok = await showAppConfirm(
      context: context,
      title: s.backupRestoreTitle,
      subtitle: fromDrive
          ? '${s.backupRestoreSubtitle}\n\n${s.backupPickDrive}'
          : s.backupRestoreSubtitle,
      confirmLabel: s.backupRestoreConfirm,
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final bytes = await BackupFile.pick(
        dialogTitle: fromDrive ? s.backupPickDrive : s.backupPickFile,
        destination: destination,
      );
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _status = s.backupCanceled);
        return;
      }
      final snapshot = BackupSnapshot.tryDecode(bytes);
      if (snapshot == null) {
        setState(() => _status = s.backupInvalid);
        return;
      }
      await widget.restoreBackup(snapshot);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await widget.onRestored();
      if (mounted) Navigator.pop(context, snapshot);
    } catch (_) {
      if (mounted) setState(() => _status = S.of(context).backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final last = _record.lastAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withOpacity(0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.backupLast,
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                last == null
                    ? s.backupNever
                    : s.backupLastLine(last, _record.lastBytes),
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.backupInventory(widget.counts),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _busy ? null : () => _setIncludePhotos(!_includePhotos),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.backupIncludePhotos,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.backupIncludePhotosHint,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _includePhotos,
                  onChanged: _busy ? null : _setIncludePhotos,
                  activeTrackColor: AppColors.accentSoft,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_busy) ...[
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(99)),
            child: LinearProgressIndicator(
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.accentSoft,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.backupBusy,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
        ],
        if (_status != null) ...[
          Text(
            _status!,
            style: const TextStyle(color: AppColors.coralSoft, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
        ],
        AppPrimaryButton(
          label: s.backupNow,
          icon: Icons.download_rounded,
          onPressed: _busy ? null : () => _backup(BackupDestination.file),
        ),
        const SizedBox(height: 10),
        AppGhostButton(
          label: s.backupToDrive,
          icon: Icons.cloud_outlined,
          accent: true,
          onPressed: _busy ? null : () => _backup(BackupDestination.drive),
        ),
        const SizedBox(height: 18),
        Text(
          s.backupRestoreSection,
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        AppGhostButton(
          label: s.backupRestore,
          icon: Icons.file_open_rounded,
          onPressed: _busy ? null : () => _restore(BackupDestination.file),
        ),
        const SizedBox(height: 10),
        AppGhostButton(
          label: s.backupRestoreFromDrive,
          icon: Icons.cloud_download_rounded,
          accent: true,
          onPressed: _busy ? null : () => _restore(BackupDestination.drive),
        ),
      ],
    );
  }
}
