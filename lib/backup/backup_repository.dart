import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class BackupRepository {
  static const mealColumns = {
    'id',
    'date',
    'name',
    'kcalPer100g',
    'weightInGrams',
    'proteinG',
    'loggedAt',
    'breakdown',
    'description',
  };
  static const imageColumns = {'id', 'mealId', 'imagePath', 'imageBlob'};
  static const weightColumns = {'id', 'date', 'weightKg'};
  static const favoriteColumns = {
    'id',
    'name',
    'kcalPer100g',
    'weightInGrams',
    'proteinG',
    'useCount',
    'lastUsed',
    'breakdown',
    'description',
  };

  final Database db;
  final SharedPreferences prefs;

  BackupRepository(this.db, this.prefs);

  Future<BackupCounts> counts() async {
    final meals = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM trackedMeals'),
        ) ??
        0;
    final photos = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM mealImages'),
        ) ??
        0;
    final weights = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM weightLogs'),
        ) ??
        0;
    final favorites = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM favoriteMeals'),
        ) ??
        0;
    return BackupCounts(
      meals: meals,
      photos: photos,
      weights: weights,
      favorites: favorites,
    );
  }

  BackupRecord record() => recordOf(prefs);

  static BackupRecord recordOf(SharedPreferences prefs) {
    final stamp = prefs.getInt(BackupRecord.lastAtKey);
    return BackupRecord(
      lastAt: stamp == null || stamp <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(stamp),
      lastBytes: prefs.getInt(BackupRecord.lastBytesKey) ?? 0,
      includePhotos: prefs.getBool(BackupRecord.includePhotosKey) ?? true,
    );
  }

  Future<void> saveIncludePhotos(bool include) {
    return prefs.setBool(BackupRecord.includePhotosKey, include);
  }

  Future<void> markSaved(BackupSnapshot snapshot, int bytes) async {
    await prefs.setInt(
      BackupRecord.lastAtKey,
      snapshot.createdAt.millisecondsSinceEpoch,
    );
    await prefs.setInt(BackupRecord.lastBytesKey, bytes);
    await prefs.setBool(BackupRecord.includePhotosKey, snapshot.includePhotos);
  }

  Future<BackupSnapshot> export({required bool includePhotos}) async {
    final meals = [
      for (final row in await db.query('trackedMeals'))
        _pick(row, mealColumns),
    ];
    final weights = [
      for (final row in await db.query('weightLogs'))
        _pick(row, weightColumns),
    ];
    final favorites = [
      for (final row in await db.query('favoriteMeals'))
        _pick(row, favoriteColumns),
    ];
    final images = <Map<String, Object?>>[];
    if (includePhotos) {
      for (final row in await db.query('mealImages')) {
        final packed = await _packImage(row);
        if (packed != null) images.add(packed);
      }
    }
    final snapshot = BackupSnapshot(
      createdAt: DateTime.now(),
      includePhotos: includePhotos,
      meals: meals,
      images: images,
      weights: weights,
      favorites: favorites,
      prefs: {
        for (final key in BackupSnapshot.prefKeys)
          if (prefs.containsKey(key)) key: BackupSnapshot.jsonSafeValue(prefs.get(key)),
      },
    );
    await prefs.setBool(BackupRecord.includePhotosKey, includePhotos);
    return snapshot;
  }

  Future<BackupCounts> restore(BackupSnapshot snapshot) async {
    Directory? documents;
    if (!kIsWeb) {
      documents = await getApplicationDocumentsDirectory();
    }

    await db.transaction((txn) async {
      await txn.delete('trackedMeals');
      await txn.delete('mealImages');
      await txn.delete('weightLogs');
      await txn.delete('favoriteMeals');

      for (final meal in snapshot.meals) {
        final row = _rowForInsert(meal, mealColumns);
        if ((row['id'] as String?)?.isEmpty ?? true) continue;
        await txn.insert('trackedMeals', row);
      }
      for (final weight in snapshot.weights) {
        final row = _rowForInsert(weight, weightColumns);
        if ((row['id'] as String?)?.isEmpty ?? true) continue;
        await txn.insert('weightLogs', row);
      }
      for (final favorite in snapshot.favorites) {
        final row = _rowForInsert(favorite, favoriteColumns);
        if ((row['id'] as String?)?.isEmpty ?? true) continue;
        await txn.insert('favoriteMeals', row);
      }
      for (final image in snapshot.images) {
        final bytes = BackupSnapshot.decodeBytes(
          image['image'] ?? image['imageBlob'] ?? image['imageBytes'],
        );
        if (bytes == null) continue;
        final mealId = image['mealId']?.toString() ?? '';
        if (mealId.isEmpty) continue;
        var imagePath = '';
        if (documents != null) {
          imagePath = '${documents.path}/${const Uuid().v4()}.jpg';
          await File(imagePath).writeAsBytes(bytes, flush: true);
        }
        await txn.insert('mealImages', {
          'id': (image['id']?.toString().isNotEmpty ?? false)
              ? image['id'].toString()
              : const Uuid().v1().toString(),
          'mealId': mealId,
          'imagePath': imagePath,
          'imageBlob': bytes,
        });
      }
    });

    for (final key in BackupSnapshot.prefKeys) {
      if (!snapshot.prefs.containsKey(key)) continue;
      await _writePref(key, snapshot.prefs[key]);
    }

    await markSaved(snapshot, snapshot.encodeBytes().length);
    return BackupCounts(
      meals: snapshot.mealCount,
      photos: snapshot.photoCount,
      weights: snapshot.weightCount,
      favorites: snapshot.favorites.length,
    );
  }

  Future<Map<String, Object?>?> _packImage(Map<String, Object?> row) async {
    var bytes = decodeMealImageBytes(row);
    final path = row['imagePath']?.toString() ?? '';
    if ((bytes == null || bytes.isEmpty) && !kIsWeb && path.isNotEmpty) {
      bytes = await loadMealImageBytes(path: path);
    }
    if (bytes == null || bytes.isEmpty) return null;
    return {
      'id': row['id']?.toString() ?? const Uuid().v1().toString(),
      'mealId': row['mealId']?.toString() ?? '',
      'image': base64Of(bytes),
    };
  }

  static String base64Of(Uint8List bytes) =>
      BackupSnapshot.jsonSafeValue(bytes) as String;

  Future<void> _writePref(String key, Object? value) async {
    final typed = BackupSnapshot.typedPrefValue(key, value);
    if (typed == null) {
      await prefs.remove(key);
      return;
    }
    if (typed is bool) {
      await prefs.setBool(key, typed);
      return;
    }
    if (typed is int) {
      await prefs.setInt(key, typed);
      return;
    }
    if (typed is double) {
      await prefs.setDouble(key, typed);
      return;
    }
    await prefs.setString(key, typed.toString());
  }

  static Map<String, Object?> _pick(Map<String, Object?> row, Set<String> columns) {
    return BackupSnapshot.jsonSafe({
      for (final key in columns)
        if (row.containsKey(key)) key: row[key],
    });
  }

  static Map<String, Object?> _rowForInsert(
    Map<String, Object?> source,
    Set<String> columns,
  ) {
    final row = <String, Object?>{};
    for (final key in columns) {
      if (!source.containsKey(key)) continue;
      var value = source[key];
      if (key == 'imageBlob') {
        value = BackupSnapshot.decodeBytes(value);
      }
      row[key] = value;
    }
    return row;
  }
}
