import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/update/update_config.dart';
import 'package:simple_calorie_tracker/update/update_lookup.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';

const _channel = MethodChannel('simple_calorie_tracker/app_update');
const _lastCheckKey = 'updateLastCheckMs';

bool get _android =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<InstalledVersion> installed() async {
  if (_android) {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getVersion');
      if (raw is Map) {
        final name = raw['versionName']?.toString() ?? '';
        final code = raw['versionCode'];
        final parsed = code is int ? code : int.tryParse(code?.toString() ?? '') ?? 0;
        if (name.isNotEmpty || parsed > 0) {
          return InstalledVersion(versionName: name, versionCode: parsed);
        }
      }
    } catch (_) {}
  }
  return const InstalledVersion(
    versionName: UpdateConfig.fallbackVersionName,
    versionCode: UpdateConfig.fallbackVersionCode,
  );
}

Future<UpdateRelease?> check({bool force = false}) async {
  if (!_android) return null;
  if (!force && !await _shouldAutoCheck()) return null;

  final current = await installed();
  UpdateRelease? found;
  try {
    final remote = await fetchNewestRelease();
    if (remote != null && remote.isNewerThan(current)) found = remote;
  } catch (_) {
    found = null;
  }

  await _markChecked();
  return found;
}

Future<bool> canInstallPackages() async {
  if (!_android) return false;
  try {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> openInstallSettings() async {
  if (!_android) return;
  try {
    await _channel.invokeMethod('openInstallSettings');
  } catch (_) {}
}

Future<String> downloadApk(
  String url, {
  void Function(double progress)? onProgress,
}) async {
  if (!_android) {
    throw UnsupportedError('Updates are only available on Android.');
  }
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    throw StateError('Update download must be HTTPS.');
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/updates/update.apk');
  await file.parent.create(recursive: true);
  if (await file.exists()) await file.delete();

  final client = http.Client();
  try {
    final request = http.Request('GET', uri);
    request.headers['User-Agent'] = UpdateConfig.userAgent;
    request.headers['Accept'] = '*/*';
    final response = await client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 400) {
      throw StateError('Update download failed (${response.statusCode}).');
    }
    final total = response.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(total > 0 ? (received / total).clamp(0, 1) : 0);
    }
    await sink.close();
    if (received <= 0) throw StateError('Update file was empty.');
    onProgress?.call(1);
    return file.path;
  } finally {
    client.close();
  }
}

Future<void> installApk(String path) async {
  if (!_android) {
    throw UnsupportedError('Updates are only available on Android.');
  }
  await _channel.invokeMethod('installApk', {'path': path});
}

Future<bool> _shouldAutoCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getInt(_lastCheckKey) ?? 0;
  return DateTime.now().millisecondsSinceEpoch - last >=
      UpdateConfig.autoCheckEvery.inMilliseconds;
}

Future<void> _markChecked() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
}
