import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_calorie_tracker/backup/backup_download.dart'
    if (dart.library.html) 'package:simple_calorie_tracker/backup/backup_download_web.dart'
    if (dart.library.io) 'package:simple_calorie_tracker/backup/backup_download_io.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';

enum BackupDestination { file, drive }

class BackupFileAction {
  final bool saved;
  final bool canceled;
  final BackupDestination destination;

  const BackupFileAction({
    required this.saved,
    this.canceled = false,
    this.destination = BackupDestination.file,
  });

  static BackupFileAction canceledAction([
    BackupDestination destination = BackupDestination.file,
  ]) =>
      BackupFileAction(saved: false, canceled: true, destination: destination);

  static BackupFileAction savedAction([
    BackupDestination destination = BackupDestination.file,
  ]) =>
      BackupFileAction(saved: true, destination: destination);

  static BackupFileAction failedAction([
    BackupDestination destination = BackupDestination.file,
  ]) =>
      BackupFileAction(saved: false, destination: destination);
}

class BackupFile {
  static Future<BackupFileAction> save(
    Uint8List bytes, {
    required BackupDestination destination,
    DateTime? now,
  }) async {
    final fileName = BackupSnapshot.datedFileName(now);
    try {
      final ok = await downloadBackupFile(bytes, fileName: fileName);
      if (!ok) return BackupFileAction.failedAction(destination);
      if (destination == BackupDestination.drive) {
        await openGoogleDrive();
      }
      return BackupFileAction.savedAction(destination);
    } catch (_) {
      return BackupFileAction.failedAction(destination);
    }
  }

  static Future<Uint8List?> pick({
    required String dialogTitle,
    BackupDestination destination = BackupDestination.file,
  }) async {
    if (destination == BackupDestination.drive) {
      await openGoogleDrive();
    }
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes;
    return null;
  }
}
