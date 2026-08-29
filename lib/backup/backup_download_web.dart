import 'dart:html' as html;

import 'package:flutter/foundation.dart';

Future<bool> downloadBackupFile(
  Uint8List bytes, {
  required String fileName,
}) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<void> openGoogleDrive() async {
  html.window.open('https://drive.google.com/drive/my-drive', '_blank');
}
