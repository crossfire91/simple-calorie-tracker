import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';
import 'package:simple_calorie_tracker/backup/backup_repository.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';
import 'package:simple_calorie_tracker/habit/rest_of_day.dart';
import 'package:simple_calorie_tracker/habit/streak.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/platform/home_widget_sync.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class CalorieSummaryScreenModel {

  Database? db;
  SharedPreferences? sharedPreferences;

  _initDbAndTable() async {
    db ??= await openDatabase('simple_calorie_tracker.db');
    await db!.execute('CREATE TABLE IF NOT EXISTS trackedMeals (kcalPer100g INTEGER, weightInGrams INTEGER, date VARCHAR(11), id VARCHAR(255))');
    await db!.execute('CREATE TABLE IF NOT EXISTS mealImages (imagePath VARCHAR(255), id VARCHAR(255), mealId VARCHAR(255))');
    await db!.execute('CREATE TABLE IF NOT EXISTS weightLogs (id VARCHAR(255), date VARCHAR(11), weightKg REAL)');
    await db!.execute(
      'CREATE TABLE IF NOT EXISTS favoriteMeals (id VARCHAR(255), name VARCHAR(255), kcalPer100g INTEGER, weightInGrams INTEGER, proteinG REAL, useCount INTEGER, lastUsed INTEGER)',
    );
    await _ensureColumn('trackedMeals', 'name', 'VARCHAR(255)');
    await _ensureColumn('trackedMeals', 'proteinG', 'REAL');
    await _ensureColumn('trackedMeals', 'loggedAt', 'INTEGER');
    await _ensureColumn('trackedMeals', 'breakdown', 'TEXT');
    await _ensureColumn('trackedMeals', 'description', 'TEXT');
    await _ensureColumn('favoriteMeals', 'breakdown', 'TEXT');
    await _ensureColumn('favoriteMeals', 'description', 'TEXT');
    await _ensureColumn('mealImages', 'imageBlob', 'BLOB');
  }

  Future<void> _ensureColumn(String table, String column, String type) async {
    final info = await db!.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db!.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  _initSharedPreferences() async {
    sharedPreferences ??= await SharedPreferences.getInstance();
  }

  String _dateKey(DateTime date) => '${date.day}.${date.month}.${date.year}';

  addFood(
    int kcalPer100g,
    int weightInGrams,
    DateTime selectedDate,
    Uint8List imageBytes,
    bool didTakeImage, {
    String? id,
    String name = '',
    double proteinG = 0,
    bool pinFavorite = false,
    String? breakdown,
    String? description,
  }) async {
    await _initDbAndTable();
    String imagePath = '';
    final savedBytes = didTakeImage && imageBytes.isNotEmpty ? imageBytes : null;
    if (!kIsWeb && savedBytes != null) {
      Directory appDocumentsDir = await getApplicationDocumentsDirectory();
      imagePath = '${appDocumentsDir.path}/${const Uuid().v4()}.jpg';
      File(imagePath).writeAsBytesSync(savedBytes);
    }

    String mealId = id ?? (const Uuid().v4().toString());

    String mealImageId = const Uuid().v1().toString();
    String dateKey = _dateKey(selectedDate);
    final now = DateTime.now();
    final loggedAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.year == selectedDate.year &&
              now.month == selectedDate.month &&
              now.day == selectedDate.day
          ? now.hour
          : 12,
      now.minute,
    ).millisecondsSinceEpoch;
    final cleanedName = name.trim();
    final protein = proteinG > 0
        ? proteinG
        : ProteinMath.estimateGrams(
            name: cleanedName,
            kcal: (kcalPer100g * weightInGrams) / 100,
          );

    if (id == null) {
      await db!.insert('trackedMeals', {
        'kcalPer100g': kcalPer100g,
        'weightInGrams': weightInGrams,
        'date': dateKey,
        'id': mealId,
        'name': cleanedName,
        'proteinG': protein,
        'loggedAt': loggedAt,
        'breakdown': breakdown ?? '',
        'description': description ?? '',
      });
    } else {
      List<Map<String, dynamic>> meal = await db!.query(
        'trackedMeals',
        where: 'id = ?',
        whereArgs: [id],
      );

      await db!.update(
        'trackedMeals',
        {'weightInGrams': (meal[0]['weightInGrams'] ?? 0) + weightInGrams},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    Map<String, dynamic>? mealImageRow;
    if (didTakeImage && savedBytes != null) {
      mealImageRow = {
        'imagePath': imagePath,
        'id': mealImageId,
        'mealId': mealId,
        'imageBlob': savedBytes,
      };
      await db!.insert('mealImages', mealImageRow);
    }

    if (pinFavorite && cleanedName.isNotEmpty && id == null) {
      await upsertFavorite(
        name: cleanedName,
        kcalPer100g: kcalPer100g,
        weightInGrams: weightInGrams,
        proteinG: protein,
        breakdown: breakdown,
        description: description,
      );
    } else if (cleanedName.isNotEmpty && id == null) {
      await _bumpFavoriteIfKnown(
        cleanedName,
        breakdown: breakdown,
        description: description,
      );
    }

    final payload = {
      'kcalPer100g': kcalPer100g,
      'weightInGrams': weightInGrams,
      'date': dateKey,
      'imagePath': imagePath,
      'id': mealId,
      'name': cleanedName,
      'proteinG': protein,
      'loggedAt': loggedAt,
      'breakdown': breakdown ?? '',
      'description': description ?? '',
    };

    await syncHomeWidget();

    if (mealImageRow != null) {
      return {
        ...payload,
        'mealImages': [mealImageRow],
      };
    }
    return payload;
  }

  updateFood({
    required String id,
    required int kcalPer100g,
    required int weightInGrams,
    required Uint8List imageBytes,
    required bool didTakeImage,
    String name = '',
    double proteinG = 0,
    bool pinFavorite = false,
    String? breakdown,
    String? description,
  }) async {
    await _initDbAndTable();
    final cleanedName = name.trim();
    final protein = proteinG > 0
        ? proteinG
        : ProteinMath.estimateGrams(
            name: cleanedName,
            kcal: (kcalPer100g * weightInGrams) / 100,
          );
    final fields = <String, Object?>{
      'kcalPer100g': kcalPer100g,
      'weightInGrams': weightInGrams,
      'name': cleanedName,
      'proteinG': protein,
      'description': description ?? '',
    };
    if (breakdown != null) fields['breakdown'] = breakdown;
    await db!.update('trackedMeals', fields, where: 'id = ?', whereArgs: [id]);

    Map<String, dynamic>? mealImageRow;
    if (didTakeImage && imageBytes.isNotEmpty) {
      String imagePath = '';
      if (!kIsWeb) {
        final appDocumentsDir = await getApplicationDocumentsDirectory();
        imagePath = '${appDocumentsDir.path}/${const Uuid().v4()}.jpg';
        File(imagePath).writeAsBytesSync(imageBytes);
      }
      mealImageRow = {
        'imagePath': imagePath,
        'id': const Uuid().v1().toString(),
        'mealId': id,
        'imageBlob': imageBytes,
      };
      await db!.insert('mealImages', mealImageRow);
    }

    if (pinFavorite && cleanedName.isNotEmpty) {
      await upsertFavorite(
        name: cleanedName,
        kcalPer100g: kcalPer100g,
        weightInGrams: weightInGrams,
        proteinG: protein,
        breakdown: breakdown,
        description: description,
      );
    }

    await syncHomeWidget();
    return _mealRow(id);
  }

  Future<Map<String, dynamic>> _mealRow(String id) async {
    final meals = await db!.query('trackedMeals', where: 'id = ?', whereArgs: [id]);
    if (meals.isEmpty) return {'id': id};
    final images = await db!.query('mealImages', where: 'mealId = ?', whereArgs: [id]);
    return {
      ...meals.first,
      'mealImages': List.from(images),
      'imagePath': images.isNotEmpty ? images.first['imagePath'] : '',
    };
  }

  getDaysItems(DateTime date) async {
    await _initDbAndTable();
    List<Map<String, dynamic>> result = [];

    List<Map<String, dynamic>> trackedMeals = await db!.query(
      'trackedMeals',
      where: 'date = ?',
      whereArgs: [_dateKey(date)],
    );

    for (int i = 0; i < trackedMeals.length; i++) {
      Map<String, dynamic> meal = {};
      meal.addAll(Map.from(trackedMeals[i]));
      List<Map<String, dynamic>> mealImages = await db!.query(
        'mealImages',
        where: 'mealId = ?',
        whereArgs: [trackedMeals[i]['id']],
      );
      meal.addAll({
        'mealImages': List.from(mealImages),
      });
      result.add(Map.from(meal));
    }

    sortMealsChronologically(result);
    return List.from(result);
  }

  static const mealSortNewestPref = 'mealSortNewestFirst';

  static int compareMealsChronologically(dynamic a, dynamic b) {
    final la = (a['loggedAt'] as num?)?.toInt() ?? 0;
    final lb = (b['loggedAt'] as num?)?.toInt() ?? 0;
    if (la != lb) return la.compareTo(lb);
    return '${a['id']}'.compareTo('${b['id']}');
  }

  static void sortMealsChronologically(List meals, {bool newestFirst = false}) {
    meals.sort((a, b) {
      final cmp = compareMealsChronologically(a, b);
      return newestFirst ? -cmp : cmp;
    });
  }

  static List<int> mealDisplayOrder(List meals, {required bool newestFirst}) {
    final indices = List<int>.generate(meals.length, (i) => i);
    indices.sort((a, b) {
      final cmp = compareMealsChronologically(meals[a], meals[b]);
      return newestFirst ? -cmp : cmp;
    });
    return indices;
  }

  deleteItem(String id) async {
    await _initDbAndTable();
    await db!.delete(
      'trackedMeals',
      where: 'id = ?',
      whereArgs: [id],
    );
    await db!.delete(
      'mealImages',
      where: 'mealId = ?',
      whereArgs: [id],
    );
    await syncHomeWidget();
  }

  calcTotalKcalConsumed(List currentDaysItems) {
    double totalKcal = 0;
    for(int i = 0; i<currentDaysItems.length;i++) {
      totalKcal += ((currentDaysItems[i]["kcalPer100g"] * currentDaysItems[i]["weightInGrams"]) / 100);
    }
    return totalKcal;
  }

  setKcalBudget(int budget) async {
    await _initSharedPreferences();

    await sharedPreferences!.setInt("kcalBudget", budget);
    await syncHomeWidget();
  }

  getKcalBudget() async {
    await _initSharedPreferences();

    return sharedPreferences!.getInt("kcalBudget") ?? 2500;
  }

  Future<void> saveGoalProfile(DailyTargetProfile profile, int budget) async {
    await _initSharedPreferences();
    final prefs = sharedPreferences!;
    await prefs.setInt("kcalBudget", budget);
    await prefs.setString("targetMode", profile.mode.name);
    await prefs.setString("goalType", profile.goal.name);
    if (profile.sex != null) {
      await prefs.setString("goalSex", profile.sex!.name);
    }
    if (profile.age != null) await prefs.setInt("goalAge", profile.age!);
    if (profile.heightCm != null) await prefs.setDouble("goalHeightCm", profile.heightCm!);
    if (profile.weightKg != null) {
      await prefs.setDouble("goalWeightKg", profile.weightKg!);
    } else {
      await prefs.remove("goalWeightKg");
    }
    await prefs.setString("goalActivity", profile.activity.name);
    await prefs.setDouble("goalPaceKgPerWeek", profile.paceKgPerWeek);
    if (profile.manualKcal != null) {
      await prefs.setInt("goalManualKcal", profile.manualKcal!);
    }
    await syncHomeWidget();
  }

  Future<DailyTargetProfile> getGoalProfile() async {
    await _initSharedPreferences();
    final prefs = sharedPreferences!;
    final alreadySet = prefs.getBool("hasSetCalorieBudget") == false;

    if (!alreadySet) {
      return DailyTargetProfile.fresh();
    }

    if (!prefs.containsKey("targetMode")) {
      return DailyTargetProfile(
        mode: TargetMode.manual,
        manualKcal: prefs.getInt("kcalBudget") ?? 2500,
      );
    }

    BiologicalSex? sex;
    final sexName = prefs.getString("goalSex");
    if (sexName != null) {
      sex = BiologicalSex.values.asNameMap()[sexName];
    }

    return DailyTargetProfile(
      mode: TargetMode.values.asNameMap()[prefs.getString("targetMode")] ?? TargetMode.calculated,
      goal: GoalType.values.asNameMap()[prefs.getString("goalType")] ?? GoalType.lose,
      sex: sex,
      age: prefs.getInt("goalAge"),
      heightCm: prefs.getDouble("goalHeightCm"),
      weightKg: prefs.getDouble("goalWeightKg"),
      activity: ActivityLevel.values.asNameMap()[prefs.getString("goalActivity")] ?? ActivityLevel.light,
      paceKgPerWeek: prefs.getDouble("goalPaceKgPerWeek") ?? 0.5,
      manualKcal: prefs.getInt("goalManualKcal") ?? prefs.getInt("kcalBudget"),
    );
  }

  Future<List<WeightEntry>> getWeightLogs() async {
    await _initDbAndTable();
    final rows = await db!.query('weightLogs');
    return JourneyMath.sortedLogs(
      rows.map(
        (row) => WeightEntry(
          id: row['id'] as String,
          dateKey: row['date'] as String,
          weightKg: (row['weightKg'] as num).toDouble(),
        ),
      ),
    );
  }

  Future<Set<String>> getTrackedDateKeys() async {
    await _initDbAndTable();
    final meals = await db!.query('trackedMeals', columns: ['date']);
    final weights = await db!.query('weightLogs', columns: ['date']);
    return {
      ...meals.map((row) => row['date'] as String),
      ...weights.map((row) => row['date'] as String),
    };
  }

  Future<Map<String, DayDigest>> getDayDigests() async {
    await _initDbAndTable();
    final meals = await db!.query('trackedMeals');
    final weights = await db!.query('weightLogs', columns: ['date']);
    final result = <String, DayDigest>{};

    for (final meal in meals) {
      final key = meal['date'] as String;
      final kcal =
          ((meal['kcalPer100g'] as num) * (meal['weightInGrams'] as num)) / 100;
      final existing = result[key];
      result[key] = DayDigest(
        dateKey: key,
        kcal: (existing?.kcal ?? 0) + kcal,
        mealCount: (existing?.mealCount ?? 0) + 1,
        hasWeight: existing?.hasWeight ?? false,
      );
    }

    for (final row in weights) {
      final key = row['date'] as String;
      final existing = result[key];
      result[key] = DayDigest(
        dateKey: key,
        kcal: existing?.kcal ?? 0,
        mealCount: existing?.mealCount ?? 0,
        hasWeight: true,
      );
    }

    return result;
  }

  Future<int> logWeight(double kg, DateTime date) async {
    await _initDbAndTable();
    await _initSharedPreferences();
    final key = _dateKey(date);
    final existing = await db!.query(
      'weightLogs',
      where: 'date = ?',
      whereArgs: [key],
    );

    if (existing.isEmpty) {
      await db!.insert('weightLogs', {
        'id': const Uuid().v4(),
        'date': key,
        'weightKg': kg,
      });
    } else {
      await db!.update(
        'weightLogs',
        {'weightKg': kg},
        where: 'date = ?',
        whereArgs: [key],
      );
    }

    final logs = await getWeightLogs();
    final latest = logs.isEmpty ? kg : logs.last.weightKg;
    await sharedPreferences!.setDouble('goalWeightKg', latest);

    final profile = await getGoalProfile();
    if (profile.mode == TargetMode.calculated) {
      final result = DailyTargetMath.tryCalculate(profile.copyWith(weightKg: latest));
      if (result != null) {
        await setKcalBudget(result.targetKcal);
        return result.targetKcal;
      }
    }

    final nextBudget = await getKcalBudget();
    await syncHomeWidget();
    return nextBudget;
  }

  Future<void> syncHomeWidget() async {
    await _initDbAndTable();
    await _initSharedPreferences();
    final today = DateTime.now();
    final items = await getDaysItems(today) as List;
    final consumed = calcTotalKcalConsumed(items) as num;
    final budget = await getKcalBudget() as num;
    final favorites = await getFavorites();
    final profile = await getGoalProfile();
    final meals = _bitesFromItems(items);
    final plan = RestOfDayMath.plan(
      consumed: consumed.toDouble(),
      budget: budget.toInt(),
      favorites: favorites,
      meals: meals,
      weightKg: profile.weightKg,
      now: today,
    );
    final tapFavs = <Map<String, Object>>[
      for (final item in plan.tapSuggestions)
        if (item.favoriteId != null)
          {
            'id': item.favoriteId!,
            'name': item.nameDe,
            'kcal': item.kcal,
          },
    ];
    for (final fav in favorites) {
      if (tapFavs.length >= 2) break;
      if (tapFavs.any((row) => row['id'] == fav.id)) continue;
      tapFavs.add({'id': fav.id, 'name': fav.name, 'kcal': fav.kcal});
    }
    final proteinPick = plan.tapSuggestions.isNotEmpty
        ? plan.tapSuggestions.first
        : null;
    final digests = await getDayDigests();
    final streak = StreakMath.currentStreak(StreakMath.mealKeys(digests));
    await HomeWidgetSync.publish(
      consumedKcal: consumed.round(),
      budgetKcal: budget.toInt(),
      dateKey: _dateKey(today),
      lang: sharedPreferences!.getString('appLang') ?? 'de',
      mealCount: items.length,
      favorites: tapFavs,
      coachLineDe: const S(AppLang.de).coachLine(plan),
      coachLineEn: const S(AppLang.en).coachLine(plan),
      coachMood: plan.mood.name,
      proteinGrams: plan.proteinGrams,
      proteinTarget: plan.proteinTarget,
      proteinName: proteinPick?.nameDe ?? '',
      proteinFavoriteId: proteinPick?.favoriteId ?? '',
      streak: streak,
    );
  }

  List<LoggedBite> _bitesFromItems(List items) {
    return items.map((item) {
      final grams = (item["weightInGrams"] as num?)?.toDouble() ?? 0;
      final per100 = (item["kcalPer100g"] as num?)?.toDouble() ?? 0;
      final stamp = item["loggedAt"];
      return LoggedBite(
        name: (item["name"] as String?) ?? '',
        kcal: grams * per100 / 100,
        proteinG: (item["proteinG"] as num?)?.toDouble() ?? 0,
        loggedAt: stamp is num
            ? DateTime.fromMillisecondsSinceEpoch(stamp.toInt())
            : null,
      );
    }).toList();
  }

  Future<List<FavoriteMeal>> getRecentQuickMeals({int limit = QuickMeals.limit}) async {
    await _initDbAndTable();
    final meals = List<Map<String, dynamic>>.from(await db!.query('trackedMeals'));
    meals.sort((a, b) {
      final la = (a['loggedAt'] as num?)?.toInt() ?? 0;
      final lb = (b['loggedAt'] as num?)?.toInt() ?? 0;
      return lb.compareTo(la);
    });
    final seen = <String>{};
    final out = <FavoriteMeal>[];
    for (final meal in meals) {
      final name = ((meal['name'] as String?) ?? '').trim();
      final key = name.toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      final grams = (meal['weightInGrams'] as num?)?.toInt() ?? 0;
      final per100 = (meal['kcalPer100g'] as num?)?.toInt() ?? 0;
      if (grams <= 0 || per100 <= 0) continue;
      out.add(
        FavoriteMeal(
          id: 'recent:${meal['id']}',
          name: name,
          kcalPer100g: per100,
          weightInGrams: grams,
          proteinG: (meal['proteinG'] as num?)?.toDouble() ?? 0,
          breakdown: (meal['breakdown'] as String?) ?? '',
          description: (meal['description'] as String?) ?? '',
        ),
      );
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<List<FavoriteMeal>> getFavorites() async {
    await _initDbAndTable();
    final rows = await db!.query('favoriteMeals');
    final list = <FavoriteMeal>[];
    for (final row in rows) {
      list.add(await _hydrateFavorite(_favoriteFromRow(row)));
    }
    list.sort((a, b) {
      final uses = b.useCount.compareTo(a.useCount);
      if (uses != 0) return uses;
      return b.lastUsed.compareTo(a.lastUsed);
    });
    return list;
  }

  FavoriteMeal _favoriteFromRow(Map<String, dynamic> row) {
    return FavoriteMeal(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      kcalPer100g: (row['kcalPer100g'] as num).toInt(),
      weightInGrams: (row['weightInGrams'] as num).toInt(),
      proteinG: (row['proteinG'] as num?)?.toDouble() ?? 0,
      useCount: (row['useCount'] as num?)?.toInt() ?? 1,
      lastUsed: (row['lastUsed'] as num?)?.toInt() ?? 0,
      breakdown: (row['breakdown'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
    );
  }

  Future<FavoriteMeal> _hydrateFavorite(FavoriteMeal fav) async {
    if (fav.breakdown.trim().isNotEmpty) return fav;
    final recovered = await _latestMealMetaForName(fav.name);
    if (recovered == null) return fav;
    final next = fav.copyWith(
      breakdown: recovered.$1,
      description: recovered.$2.trim().isNotEmpty ? recovered.$2 : fav.description,
    );
    await db!.update(
      'favoriteMeals',
      {
        if (next.breakdown.isNotEmpty) 'breakdown': next.breakdown,
        if (next.description.isNotEmpty) 'description': next.description,
      },
      where: 'id = ?',
      whereArgs: [fav.id],
    );
    return next;
  }

  Future<(String, String)?> _latestMealMetaForName(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    final meals = List<Map<String, dynamic>>.from(await db!.query('trackedMeals'));
    meals.sort((a, b) {
      final la = (a['loggedAt'] as num?)?.toInt() ?? 0;
      final lb = (b['loggedAt'] as num?)?.toInt() ?? 0;
      return lb.compareTo(la);
    });
    for (final meal in meals) {
      final mealName = ((meal['name'] as String?) ?? '').trim().toLowerCase();
      if (mealName != key) continue;
      final breakdown = (meal['breakdown'] as String?) ?? '';
      final description = (meal['description'] as String?) ?? '';
      if (breakdown.trim().isEmpty && description.trim().isEmpty) continue;
      return (breakdown, description);
    }
    return null;
  }

  Future<FavoriteMeal> upsertFavorite({
    required String name,
    required int kcalPer100g,
    required int weightInGrams,
    double proteinG = 0,
    String? breakdown,
    String? description,
  }) async {
    await _initDbAndTable();
    final cleaned = name.trim();
    final rows = await db!.query('favoriteMeals');
    final match = rows.cast<Map<String, dynamic>>().where((row) {
      return ((row['name'] as String?) ?? '').trim().toLowerCase() ==
          cleaned.toLowerCase();
    });
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextBreakdown = (breakdown ?? '').trim();
    final nextDescription = (description ?? '').trim();
    if (match.isNotEmpty) {
      final existing = _favoriteFromRow(match.first);
      final next = existing.copyWith(
        useCount: existing.useCount + 1,
        lastUsed: now,
        weightInGrams: weightInGrams,
        proteinG: proteinG,
        breakdown: nextBreakdown.isNotEmpty ? nextBreakdown : existing.breakdown,
        description: nextDescription.isNotEmpty ? nextDescription : existing.description,
      );
      await db!.update(
        'favoriteMeals',
        {
          'kcalPer100g': kcalPer100g,
          'weightInGrams': next.weightInGrams,
          'proteinG': next.proteinG,
          'useCount': next.useCount,
          'lastUsed': next.lastUsed,
          if (nextBreakdown.isNotEmpty) 'breakdown': next.breakdown,
          if (nextDescription.isNotEmpty) 'description': next.description,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      await syncHomeWidget();
      return next;
    }

    final fav = FavoriteMeal(
      id: const Uuid().v4(),
      name: cleaned,
      kcalPer100g: kcalPer100g,
      weightInGrams: weightInGrams,
      proteinG: proteinG,
      useCount: 1,
      lastUsed: now,
      breakdown: nextBreakdown,
      description: nextDescription,
    );
    await db!.insert('favoriteMeals', {
      'id': fav.id,
      'name': fav.name,
      'kcalPer100g': fav.kcalPer100g,
      'weightInGrams': fav.weightInGrams,
      'proteinG': fav.proteinG,
      'useCount': fav.useCount,
      'lastUsed': fav.lastUsed,
      'breakdown': fav.breakdown,
      'description': fav.description,
    });
    await syncHomeWidget();
    return fav;
  }

  Future<void> _bumpFavoriteIfKnown(
    String name, {
    String? breakdown,
    String? description,
  }) async {
    await _initDbAndTable();
    final rows = await db!.query('favoriteMeals');
    for (final row in rows) {
      final existing = (row['name'] as String?) ?? '';
      if (existing.trim().toLowerCase() != name.trim().toLowerCase()) continue;
      final nextBreakdown = (breakdown ?? '').trim();
      final nextDescription = (description ?? '').trim();
      await db!.update(
        'favoriteMeals',
        {
          'useCount': ((row['useCount'] as num?)?.toInt() ?? 1) + 1,
          'lastUsed': DateTime.now().millisecondsSinceEpoch,
          if (nextBreakdown.isNotEmpty) 'breakdown': nextBreakdown,
          if (nextDescription.isNotEmpty) 'description': nextDescription,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      return;
    }
  }

  Future<void> deleteFavorite(String id) async {
    await _initDbAndTable();
    await db!.delete('favoriteMeals', where: 'id = ?', whereArgs: [id]);
    await syncHomeWidget();
  }

  Future<List<MealPhoto>> getRecentMealPhotos({int limit = 24}) async {
    await _initDbAndTable();
    final images = await db!.query('mealImages');
    final meals = await db!.query('trackedMeals');
    final byId = {
      for (final meal in meals) meal['id'] as String: meal,
    };
    final photos = <MealPhoto>[];
    for (final image in images) {
      final meal = byId[image['mealId']];
      if (meal == null) continue;
      final grams = (meal['weightInGrams'] as num?)?.toDouble() ?? 0;
      final per100 = (meal['kcalPer100g'] as num?)?.toDouble() ?? 0;
      photos.add(
        MealPhoto(
          dateKey: meal['date'] as String,
          name: (meal['name'] as String?) ?? '',
          kcal: grams * per100 / 100,
          imagePath: (image['imagePath'] as String?) ?? '',
          imageBytes: decodeMealImageBytes(image),
        ),
      );
    }
    DateTime safeDate(String key) {
      try {
        return JourneyMath.parseDateKey(key);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    photos.sort((a, b) => safeDate(b.dateKey).compareTo(safeDate(a.dateKey)));
    if (photos.length <= limit) return photos;
    return photos.sublist(0, limit);
  }

  Future<BackupRepository> _backupRepo() async {
    await _initDbAndTable();
    await _initSharedPreferences();
    return BackupRepository(db!, sharedPreferences!);
  }

  Future<BackupCounts> backupCounts() async {
    return (await _backupRepo()).counts();
  }

  Future<BackupRecord> backupRecord() async {
    await _initSharedPreferences();
    return BackupRepository.recordOf(sharedPreferences!);
  }

  Future<void> setBackupIncludePhotos(bool include) async {
    await (await _backupRepo()).saveIncludePhotos(include);
  }

  Future<BackupSnapshot> createBackup({required bool includePhotos}) async {
    return (await _backupRepo()).export(includePhotos: includePhotos);
  }

  Future<void> markBackupSaved(BackupSnapshot snapshot, int bytes) async {
    await (await _backupRepo()).markSaved(snapshot, bytes);
  }

  Future<BackupCounts> restoreBackup(BackupSnapshot snapshot) async {
    final counts = await (await _backupRepo()).restore(snapshot);
    await syncHomeWidget();
    return counts;
  }
}

class DayDigest {
  final String dateKey;
  final double kcal;
  final int mealCount;
  final bool hasWeight;

  const DayDigest({
    required this.dateKey,
    this.kcal = 0,
    this.mealCount = 0,
    this.hasWeight = false,
  });

  bool get hasMeals => mealCount > 0;
  bool get isLogged => hasMeals || hasWeight;
}