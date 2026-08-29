import 'dart:convert';
import 'dart:typed_data';

class BackupSnapshot {
  static const formatId = 'simple_calorie_tracker';
  static const formatVersion = 1;
  static const fileName = 'calorie_tracker_backup.sctbackup';

  static String datedFileName([DateTime? now]) {
    final date = now ?? DateTime.now();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return 'calorie_tracker_${date.year}-$month-$day.sctbackup';
  }

  static const prefKeys = {
    'kcalBudget',
    'hasSetCalorieBudget',
    'targetMode',
    'goalType',
    'goalSex',
    'goalAge',
    'goalHeightCm',
    'goalWeightKg',
    'goalActivity',
    'goalPaceKgPerWeek',
    'goalManualKcal',
    'appLang',
    'mealSortNewestFirst',
    'hideJourneyWeight',
    'geminiApiKey',
    'usdaApiKey',
  };

  static const intPrefKeys = {
    'kcalBudget',
    'goalAge',
    'goalManualKcal',
  };
  static const doublePrefKeys = {
    'goalHeightCm',
    'goalWeightKg',
    'goalPaceKgPerWeek',
  };
  static const boolPrefKeys = {
    'hasSetCalorieBudget',
    'mealSortNewestFirst',
    'hideJourneyWeight',
  };

  final DateTime createdAt;
  final bool includePhotos;
  final List<Map<String, Object?>> meals;
  final List<Map<String, Object?>> images;
  final List<Map<String, Object?>> weights;
  final List<Map<String, Object?>> favorites;
  final Map<String, Object?> prefs;

  const BackupSnapshot({
    required this.createdAt,
    required this.includePhotos,
    required this.meals,
    required this.images,
    required this.weights,
    required this.favorites,
    required this.prefs,
  });

  int get mealCount => meals.length;
  int get photoCount => images.length;
  int get weightCount => weights.length;

  Map<String, Object?> toJson() => {
        'format': formatId,
        'version': formatVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'includePhotos': includePhotos,
        'meals': meals,
        'images': images,
        'weights': weights,
        'favorites': favorites,
        'prefs': prefs,
      };

  String encode() => jsonEncode(toJson());

  Uint8List encodeBytes() => Uint8List.fromList(utf8.encode(encode()));

  static BackupSnapshot? tryDecode(dynamic raw) {
    try {
      return decode(raw);
    } catch (_) {
      return null;
    }
  }

  static BackupSnapshot decode(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) {
      throw const FormatException('Backup is not a JSON object.');
    }
    final format = map['format']?.toString();
    if (format != null && format != formatId) {
      throw const FormatException('Unknown backup format.');
    }
    final version = (map['version'] as num?)?.toInt() ?? 1;
    if (version > formatVersion) {
      throw const FormatException('Backup is from a newer app version.');
    }
    final createdRaw = map['createdAt']?.toString();
    final createdAt = createdRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(createdRaw);
    return BackupSnapshot(
      createdAt: createdAt.toLocal(),
      includePhotos: map['includePhotos'] == true,
      meals: _objectList(map['meals']),
      images: _objectList(map['images']),
      weights: _objectList(map['weights']),
      favorites: _objectList(map['favorites']),
      prefs: _prefsMap(map['prefs']),
    );
  }

  static Map<String, Object?> jsonSafe(Map<String, Object?> row) {
    return {
      for (final entry in row.entries) entry.key: jsonSafeValue(entry.value),
    };
  }

  static Object? jsonSafeValue(Object? value) {
    if (value == null) return null;
    if (value is bool || value is String) return value;
    if (value is int || value is double) return value;
    if (value is Uint8List) return value.isEmpty ? null : base64Encode(value);
    if (value is List<int>) {
      return value.isEmpty ? null : base64Encode(Uint8List.fromList(value));
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is num) return value.toDouble();
    return value.toString();
  }

  static Uint8List? decodeBytes(Object? raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw.isEmpty ? null : raw;
    if (raw is List<int>) {
      return raw.isEmpty ? null : Uint8List.fromList(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final bytes = base64Decode(raw);
        return bytes.isEmpty ? null : bytes;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Map<String, Object?>? _asMap(dynamic raw) {
    if (raw is BackupSnapshot) return raw.toJson();
    if (raw is Map) {
      return {
        for (final entry in raw.entries) entry.key.toString(): entry.value,
      };
    }
    if (raw is Uint8List) {
      return _asMap(utf8.decode(raw));
    }
    if (raw is List<int>) {
      return _asMap(utf8.decode(raw));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries) entry.key.toString(): entry.value,
        };
      }
    }
    return null;
  }

  static List<Map<String, Object?>> _objectList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          {
            for (final entry in item.entries)
              entry.key.toString(): jsonSafeValue(entry.value),
          },
    ];
  }

  static Map<String, Object?> _prefsMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      if (!prefKeys.contains(key)) continue;
      out[key] = typedPrefValue(key, entry.value);
    }
    return out;
  }

  static Object? typedPrefValue(String key, Object? value) {
    if (value == null) return null;
    if (boolPrefKeys.contains(key)) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value == 'true' || value == '1';
      return null;
    }
    if (intPrefKeys.contains(key)) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }
    if (doublePrefKeys.contains(key)) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }
    return value.toString();
  }
}

class BackupCounts {
  final int meals;
  final int photos;
  final int weights;
  final int favorites;

  const BackupCounts({
    this.meals = 0,
    this.photos = 0,
    this.weights = 0,
    this.favorites = 0,
  });
}

class BackupRecord {
  static const lastAtKey = 'backupLastAt';
  static const lastBytesKey = 'backupLastBytes';
  static const includePhotosKey = 'backupIncludePhotos';

  final DateTime? lastAt;
  final int lastBytes;
  final bool includePhotos;

  const BackupRecord({
    this.lastAt,
    this.lastBytes = 0,
    this.includePhotos = true,
  });

  BackupRecord copyWith({
    DateTime? lastAt,
    int? lastBytes,
    bool? includePhotos,
  }) {
    return BackupRecord(
      lastAt: lastAt ?? this.lastAt,
      lastBytes: lastBytes ?? this.lastBytes,
      includePhotos: includePhotos ?? this.includePhotos,
    );
  }
}
