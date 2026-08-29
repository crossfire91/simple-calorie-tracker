import 'dart:convert';

class InstalledVersion {
  final String versionName;
  final int versionCode;

  const InstalledVersion({
    required this.versionName,
    required this.versionCode,
  });

  String get label => versionCode > 0 ? '$versionName ($versionCode)' : versionName;
}

class UpdateRelease {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String notes;

  const UpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    this.notes = '',
  });

  bool get hasApk => apkUrl.startsWith('https://');

  bool isNewerThan(InstalledVersion installed) {
    if (!hasApk) return false;
    if (versionCode > 0 && installed.versionCode > 0) {
      return versionCode > installed.versionCode;
    }
    return compareSemver(versionName, installed.versionName) > 0;
  }

  factory UpdateRelease.fromJson(Map<dynamic, dynamic> json) {
    final versionName = _firstString(json, const [
      'versionName',
      'version',
      'name',
      'tag',
    ]);
    final versionCode = _firstInt(json, const [
      'versionCode',
      'version_code',
      'build',
    ]);
    final apkUrl = _firstString(json, const [
      'apkUrl',
      'apk_url',
      'url',
      'downloadUrl',
      'download_url',
    ]);
    final notes = _firstString(json, const ['notes', 'changelog', 'body']);
    return UpdateRelease(
      versionName: versionName,
      versionCode: versionCode,
      apkUrl: apkUrl,
      notes: notes,
    );
  }
}

int compareSemver(String rawA, String rawB) {
  final a = parseVersionToken(rawA);
  final b = parseVersionToken(rawB);
  for (var i = 0; i < 3; i++) {
    final delta = a.parts[i] - b.parts[i];
    if (delta != 0) return delta;
  }
  return a.code - b.code;
}

({List<int> parts, int code}) parseVersionToken(String raw) {
  final cleaned = raw.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
  final plus = cleaned.split('+');
  final core = plus.first.split('-').first;
  final numbers = core.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  while (numbers.length < 3) {
    numbers.add(0);
  }
  final code = plus.length > 1 ? int.tryParse(plus[1]) ?? 0 : 0;
  return (parts: numbers.take(3).toList(), code: code);
}

UpdateRelease? parseManifest(String body) {
  final decoded = _asMap(body);
  if (decoded == null) return null;
  final release = UpdateRelease.fromJson(decoded);
  if (release.versionName.isEmpty && release.versionCode <= 0) return null;
  return release;
}

UpdateRelease? parseGithubRelease(String body) {
  final decoded = _asMap(body);
  if (decoded == null) return null;
  final tag = (decoded['tag_name'] ?? decoded['name'] ?? '').toString();
  final parsed = parseVersionToken(tag);
  final fromBody = _versionCodeInText((decoded['body'] ?? '').toString());
  final assets = decoded['assets'];
  var apkUrl = '';
  if (assets is List) {
    for (final raw in assets) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString().toLowerCase();
      final url = (raw['browser_download_url'] ?? '').toString();
      if (url.startsWith('https://') && name.endsWith('.apk')) {
        apkUrl = url;
        break;
      }
    }
  }
  if (apkUrl.isEmpty) return null;
  final notes = (decoded['body'] ?? '').toString().trim();
  return UpdateRelease(
    versionName: [
      parsed.parts[0],
      parsed.parts[1],
      parsed.parts[2],
    ].join('.'),
    versionCode: fromBody > 0 ? fromBody : parsed.code,
    apkUrl: apkUrl,
    notes: notes,
  );
}

int _versionCodeInText(String text) {
  final match = RegExp(r'version[_ ]?code\s*[:=]\s*(\d+)', caseSensitive: false)
      .firstMatch(text);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

Map<String, dynamic>? _asMap(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

int _firstInt(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

String _firstString(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
