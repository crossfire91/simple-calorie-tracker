import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';

void main() {
  test('backup roundtrip keeps meals, photos and typed prefs', () {
    final photo = Uint8List.fromList([1, 2, 3, 4]);
    final snapshot = BackupSnapshot(
      createdAt: DateTime.utc(2026, 8, 29, 20, 40),
      includePhotos: true,
      meals: const [
        {
          'id': 'meal-1',
          'date': '29.8.2026',
          'name': 'Quark',
          'kcalPer100g': 67,
          'weightInGrams': 200,
          'proteinG': 24.0,
          'loggedAt': 1756495200000,
          'breakdown': '',
          'description': 'Magerquark',
        },
      ],
      images: [
        {
          'id': 'img-1',
          'mealId': 'meal-1',
          'image': base64Encode(photo),
        },
      ],
      weights: const [
        {'id': 'w1', 'date': '29.8.2026', 'weightKg': 81.4},
      ],
      favorites: const [
        {
          'id': 'fav-1',
          'name': 'Quark',
          'kcalPer100g': 67,
          'weightInGrams': 200,
          'proteinG': 24.0,
          'useCount': 3,
          'lastUsed': 1756495200000,
        },
      ],
      prefs: const {
        'kcalBudget': 2100,
        'hasSetCalorieBudget': false,
        'goalHeightCm': 168.0,
        'goalWeightKg': 81.4,
        'goalPaceKgPerWeek': 0.5,
        'appLang': 'de',
        'geminiApiKey': 'secret',
      },
    );

    final restored = BackupSnapshot.decode(snapshot.encodeBytes());

    expect(restored.mealCount, 1);
    expect(restored.photoCount, 1);
    expect(restored.meals.single['name'], 'Quark');
    expect(BackupSnapshot.decodeBytes(restored.images.single['image']), photo);
    expect(restored.prefs['kcalBudget'], 2100);
    expect(restored.prefs['hasSetCalorieBudget'], isFalse);
    expect(restored.prefs['goalHeightCm'], 168.0);
    expect(restored.prefs['goalWeightKg'], 81.4);
    expect(restored.prefs['appLang'], 'de');
    expect(restored.includePhotos, isTrue);
  });

  test('unknown prefs and foreign formats are rejected', () {
    expect(BackupSnapshot.tryDecode('{"hello":true}'), isNotNull);
    expect(
      BackupSnapshot.tryDecode('{"format":"whatsapp","version":1}'),
      isNull,
    );
    expect(
      BackupSnapshot.tryDecode('{"format":"simple_calorie_tracker","version":99}'),
      isNull,
    );

    final restored = BackupSnapshot.decode({
      'format': BackupSnapshot.formatId,
      'version': 1,
      'prefs': {
        'kcalBudget': 1800,
        'updateSkipCode': 44,
        'goalHeightCm': 168,
      },
    });
    expect(restored.prefs.containsKey('updateSkipCode'), isFalse);
    expect(restored.prefs['goalHeightCm'], 168.0);
    expect(restored.prefs['kcalBudget'], 1800);
  });

  test('dated backup file name stays stable', () {
    expect(
      BackupSnapshot.datedFileName(DateTime(2026, 8, 29)),
      'calorie_tracker_2026-08-29.sctbackup',
    );
  });

  test('photos can be omitted from the portable file', () {
    final snapshot = BackupSnapshot(
      createdAt: DateTime.utc(2026, 8, 29),
      includePhotos: false,
      meals: const [
        {'id': 'meal-1', 'date': '29.8.2026', 'kcalPer100g': 100, 'weightInGrams': 100},
      ],
      images: const [],
      weights: const [],
      favorites: const [],
      prefs: const {},
    );

    final restored = BackupSnapshot.decode(snapshot.encode());
    expect(restored.includePhotos, isFalse);
    expect(restored.images, isEmpty);
    expect(restored.mealCount, 1);
  });
}
