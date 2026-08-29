import 'package:simple_calorie_tracker/update/update_config.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';

Future<InstalledVersion> installed() async {
  return const InstalledVersion(
    versionName: UpdateConfig.fallbackVersionName,
    versionCode: UpdateConfig.fallbackVersionCode,
  );
}

Future<UpdateRelease?> check({bool force = false}) async => null;

Future<bool> canInstallPackages() async => false;

Future<void> openInstallSettings() async {}

Future<String> downloadApk(
  String url, {
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('Updates are only available on Android.');
}

Future<void> installApk(String path) async {
  throw UnsupportedError('Updates are only available on Android.');
}
