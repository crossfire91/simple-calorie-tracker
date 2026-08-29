import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';

Future<bool> downloadBackupFile(
  Uint8List bytes, {
  required String fileName,
}) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: fileName,
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['sctbackup', 'json'],
    );
    if (path != null) {
      if (path.isNotEmpty && !kIsWeb) {
        final file = File(path);
        if (!await file.exists()) {
          await file.writeAsBytes(bytes, flush: true);
        }
      }
      return true;
    }
  } catch (_) {}

  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${BackupSnapshot.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    final result = await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/json',
          name: fileName,
        ),
      ],
    );
    return result.status != ShareResultStatus.dismissed;
  } catch (_) {
    return false;
  }
}

Future<void> openGoogleDrive() async {}
