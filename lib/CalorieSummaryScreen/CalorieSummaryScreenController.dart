import 'package:flutter/services.dart';

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

  upsertFavorite({
    required String name,
    required int kcalPer100g,
    required int weightInGrams,
    double proteinG = 0,
  }) async {
    return await model.upsertFavorite(
      name: name,
      kcalPer100g: kcalPer100g,
      weightInGrams: weightInGrams,
      proteinG: proteinG,
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

}