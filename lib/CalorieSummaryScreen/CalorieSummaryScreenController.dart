import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';

class CalorieSummaryScreenController{

  var view;
  var model;

  CalorieSummaryScreenController(this.view, this.model);

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
    return await model.addFood(
      kcalPer100g,
      weightInGrams,
      selectedDate,
      imageBytes,
      didTakeImage,
      id: id,
      name: name,
      proteinG: proteinG,
      pinFavorite: pinFavorite,
      breakdown: breakdown,
      description: description,
    );
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
    return await model.updateFood(
      id: id,
      kcalPer100g: kcalPer100g,
      weightInGrams: weightInGrams,
      imageBytes: imageBytes,
      didTakeImage: didTakeImage,
      name: name,
      proteinG: proteinG,
      pinFavorite: pinFavorite,
      breakdown: breakdown,
      description: description,
    );
  }

  getDaysItems(DateTime date) async {
    return await model.getDaysItems(date);
  }

  deleteItem(String id) async {
    await model.deleteItem(id);
  }

  calcTotalKcalConsumed(List currentDaysItems) {
    return model.calcTotalKcalConsumed(currentDaysItems);
  }

  setKcalBudget(int budget) async {
    await model.setKcalBudget(budget);
  }

  getKcalBudget() async {
    return await model.getKcalBudget();
  }

  saveGoalProfile(profile, int budget) async {
    await model.saveGoalProfile(profile, budget);
  }

  getGoalProfile() async {
    return await model.getGoalProfile();
  }

  getWeightLogs() async {
    return await model.getWeightLogs();
  }

  logWeight(double kg, DateTime date) async {
    return await model.logWeight(kg, date);
  }

  getTrackedDateKeys() async {
    return await model.getTrackedDateKeys();
  }

  getDayDigests() async {
    return await model.getDayDigests();
  }

  getFavorites() async {
    return await model.getFavorites();
  }

  getRecentQuickMeals() async {
    return await model.getRecentQuickMeals();
  }

  upsertFavorite({
    required String name,
    required int kcalPer100g,
    required int weightInGrams,
    double proteinG = 0,
    String? breakdown,
    String? description,
  }) async {
    return await model.upsertFavorite(
      name: name,
      kcalPer100g: kcalPer100g,
      weightInGrams: weightInGrams,
      proteinG: proteinG,
      breakdown: breakdown,
      description: description,
    );
  }

  deleteFavorite(String id) async {
    await model.deleteFavorite(id);
  }

  getRecentMealPhotos() async {
    return await model.getRecentMealPhotos();
  }

  syncHomeWidget() async {
    await model.syncHomeWidget();
  }

  Future<BackupCounts> backupCounts() async {
    return await model.backupCounts();
  }

  Future<BackupRecord> backupRecord() async {
    return await model.backupRecord();
  }

  Future<void> setBackupIncludePhotos(bool include) async {
    await model.setBackupIncludePhotos(include);
  }

  Future<BackupSnapshot> createBackup({required bool includePhotos}) async {
    return await model.createBackup(includePhotos: includePhotos);
  }

  Future<void> markBackupSaved(BackupSnapshot snapshot, int bytes) async {
    await model.markBackupSaved(snapshot, bytes);
  }

  Future<BackupCounts> restoreBackup(BackupSnapshot snapshot) async {
    return await model.restoreBackup(snapshot);
  }

}