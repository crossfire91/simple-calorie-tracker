class UpdateConfig {
  /// Public HTTPS JSON the app checks. Upload APK anywhere, then put its
  /// link here via [updates/latest.json] on GitHub / a gist / any host.
  /// Override at build time: --dart-define=UPDATE_MANIFEST_URL=https://...
  static const manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/crossfire91/simple-calorie-tracker/main/updates/latest.json',
  );

  /// If the JSON is missing, the app reads GitHub Releases instead.
  /// Create a public repo, attach the APK to a release, tag it `v1.2.0`.
  static const githubRepo = String.fromEnvironment(
    'UPDATE_GITHUB_REPO',
    defaultValue: 'crossfire91/simple-calorie-tracker',
  );

  static const fallbackVersionName = '1.2.0';
  static const fallbackVersionCode = 3;

  static const autoCheckEvery = Duration(hours: 4);
  static const userAgent = 'SimpleCalorieTracker/1.2 (update-check)';
}
