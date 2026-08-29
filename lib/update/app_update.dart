import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/update/app_update_stub.dart'
    if (dart.library.io) 'package:simple_calorie_tracker/update/app_update_io.dart'
    as impl;
import 'package:simple_calorie_tracker/update/update_lookup.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';

class UpdateStatus {
  final InstalledVersion installed;
  final UpdateRelease? newer;
  final bool checked;

  const UpdateStatus({
    required this.installed,
    this.newer,
    this.checked = false,
  });

  bool get isCurrent => checked && newer == null;
  bool get hasUpdate => newer != null;
}

class AppUpdate {
  static const _skipKey = 'updateSkippedCode';
  static const _promptedKey = 'updatePromptedCode';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<InstalledVersion> installed() => impl.installed();

  static Future<UpdateStatus> status() async {
    final current = await installed();
    try {
      final remote = await fetchNewestRelease();
      if (remote == null) {
        return UpdateStatus(installed: current, checked: false);
      }
      if (remote.isNewerVersionThan(current)) {
        return UpdateStatus(installed: current, newer: remote, checked: true);
      }
      return UpdateStatus(installed: current, checked: true);
    } catch (_) {
      return UpdateStatus(installed: current, checked: false);
    }
  }

  static Future<UpdateRelease?> check({bool force = false}) {
    if (!isSupported) return Future.value(null);
    return impl.check(force: force);
  }

  static Future<bool> canInstallPackages() => impl.canInstallPackages();

  static Future<void> openInstallSettings() => impl.openInstallSettings();

  static Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) {
    return impl.downloadApk(url, onProgress: onProgress);
  }

  static Future<void> installApk(String path) => impl.installApk(path);

  static Future<void> downloadAndInstall(
    UpdateRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final path = await downloadApk(release.apkUrl, onProgress: onProgress);
    await installApk(path);
  }

  static Future<bool> shouldPrompt(UpdateRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_promptedKey) != _codeOf(release);
  }

  static Future<void> markPrompted(UpdateRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_promptedKey, _codeOf(release));
  }

  static Future<bool> isSkipped(UpdateRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_skipKey) == _codeOf(release);
  }

  static Future<void> skip(UpdateRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipKey, _codeOf(release));
  }

  static int _codeOf(UpdateRelease release) {
    if (release.versionCode > 0) return release.versionCode;
    final parsed = parseVersionToken(release.versionName);
    return parsed.parts[0] * 1000000 + parsed.parts[1] * 1000 + parsed.parts[2];
  }
}
