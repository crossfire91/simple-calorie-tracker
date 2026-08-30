import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/AddFoodAlertBody/AddFoodAlertBody.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/GalleryAlert/GalleryAlertBody.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/widgets/api_keys_form.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';
import 'package:simple_calorie_tracker/widgets/backup_form.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/ring_slices.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';
import 'package:simple_calorie_tracker/habit/streak.dart';
import 'package:simple_calorie_tracker/widgets/calorie_calendar.dart';
import 'package:simple_calorie_tracker/widgets/calorie_ring.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/nutrition/api_keys.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/widgets/daily_target_form.dart';
import 'package:simple_calorie_tracker/widgets/favorite_meals_strip.dart';
import 'package:simple_calorie_tracker/widgets/settings_menu.dart';
import 'package:simple_calorie_tracker/widgets/meal_card.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';
import 'package:simple_calorie_tracker/widgets/meal_photo_feed.dart';
import 'package:simple_calorie_tracker/widgets/relative_day_chip.dart';
import 'package:simple_calorie_tracker/widgets/rest_of_day_coach.dart';
import 'package:simple_calorie_tracker/widgets/tracked_days_strip.dart';
import 'package:simple_calorie_tracker/widgets/weight_journey_card.dart';
import 'package:simple_calorie_tracker/widgets/weight_log_form.dart';
import 'package:simple_calorie_tracker/platform/home_widget_sync.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/widgets/update_banner.dart';

class CalorieSummaryScreenView extends StatefulWidget {
  var observer;

  void registerObserver(var controller) {
    observer = controller;
  }

  @override
  State<CalorieSummaryScreenView> createState() => CcalorieSummaryScreenViewState();
}

class CcalorieSummaryScreenViewState extends State<CalorieSummaryScreenView> {
  DateTime selectedDate = DateTime.now();
  List currentDaysItems = [];
  int kcalBudget = 2500;
  SharedPreferences? sharedPreferences;
  double totalKcalConsumed = 0;
  WeightSnapshot? journey;
  Map<String, DayDigest> dayDigests = {};
  List<FavoriteMeal> favorites = [];
  List<FavoriteMeal> recentMeals = [];
  List<MealPhoto> weekPhotos = [];
  bool _celebrate = false;
  bool _hasGemini = false;
  bool _newestMealsFirst = true;
  final ValueNotifier<int?> _ringFocus = ValueNotifier<int?>(null);
  UpdateStatus? _updateStatus;

  updateChart() {
    totalKcalConsumed = widget.observer.calcTotalKcalConsumed(currentDaysItems);
    setState(() {});
  }

  Future<void> _reloadDigests() async {
    final next = await widget.observer.getDayDigests() as Map<String, DayDigest>;
    final favs = (await widget.observer.getFavorites() as List).cast<FavoriteMeal>();
    final recents = (await widget.observer.getRecentQuickMeals() as List).cast<FavoriteMeal>();
    final photos = (await widget.observer.getRecentMealPhotos() as List).cast<MealPhoto>();
    if (!mounted) return;
    setState(() {
      dayDigests = next;
      favorites = favs;
      recentMeals = recents;
      weekPhotos = photos;
    });
  }

  List<FavoriteMeal> get _quickMeals => QuickMeals.merge(
        favorites: favorites,
        recent: recentMeals,
      );

  List<LoggedBite> get _todayBites {
    return currentDaysItems.map((item) {
      final grams = (item["weightInGrams"] as num).toDouble();
      final per100 = (item["kcalPer100g"] as num).toDouble();
      final kcal = grams * per100 / 100;
      final name = (item["name"] as String?) ?? '';
      final protein = (item["proteinG"] as num?)?.toDouble() ?? 0;
      final stamp = item["loggedAt"];
      return LoggedBite(
        name: name,
        kcal: kcal,
        proteinG: protein,
        loggedAt: stamp is num
            ? DateTime.fromMillisecondsSinceEpoch(stamp.toInt())
            : null,
      );
    }).toList();
  }

  double get _yesterdayKcal {
    final key = JourneyMath.dateKey(selectedDate.subtract(const Duration(days: 1)));
    return dayDigests[key]?.kcal ?? 0;
  }

  bool get _isToday => JourneyMath.sameDay(selectedDate, DateTime.now());

  bool get _isFuture =>
      JourneyMath.dayOnly(selectedDate).isAfter(JourneyMath.dayOnly(DateTime.now()));

  Future<void> _afterMealChange(double before) async {
    currentDaysItems = await widget.observer.getDaysItems(selectedDate);
    updateChart();
    await _reloadJourney();
    await _reloadDigests();
    if (!mounted) return;
    if (_isToday &&
        StreakMath.ringJustClosed(before, totalKcalConsumed, kcalBudget)) {
      HapticFeedback.heavyImpact();
      setState(() => _celebrate = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _celebrate = false);
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _selectDate(DateTime date) async {
    selectedDate = date;
    _ringFocus.value = null;
    setState(() {});
    currentDaysItems = await widget.observer.getDaysItems(date);
    updateChart();
  }

  void _setRingFocus(int? next) {
    _ringFocus.value = next;
  }

  void _toggleRingFocus(int mealIndex) {
    _setRingFocus(_ringFocus.value == mealIndex ? null : mealIndex);
  }

  Future<void> _setMealSortNewest(bool newest) async {
    if (_newestMealsFirst == newest) return;
    HapticFeedback.selectionClick();
    setState(() => _newestMealsFirst = newest);
    sharedPreferences ??= await SharedPreferences.getInstance();
    await sharedPreferences!.setBool(CalorieSummaryScreenModel.mealSortNewestPref, newest);
  }

  Future<void> _showWelcome({bool firstRun = false}) async {
    final profile = await widget.observer.getGoalProfile();
    if (!mounted) return;
    final s = S.of(context);
    await showAppDialog(
      context: context,
      barrierDismissible: !firstRun,
      child: AppDialogCard(
        showClose: !firstRun,
        icon: Icons.auto_awesome_rounded,
        title: firstRun ? s.welcomeTitle : s.dailyTarget,
        subtitle: firstRun ? s.welcomeSubtitle : s.dailyTargetSubtitle,
        child: DailyTargetForm(
          initial: profile,
          firstRun: firstRun,
          onSave: (kcal, saved) async {
            await widget.observer.saveGoalProfile(saved, kcal);
            kcalBudget = kcal;
            sharedPreferences ??= await SharedPreferences.getInstance();
            await sharedPreferences!.setBool("hasSetCalorieBudget", false);
            if (saved.weightKg != null) {
              final latest = journey?.currentKg;
              if (latest == null || (latest - saved.weightKg!).abs() >= 0.05) {
                kcalBudget = await widget.observer.logWeight(saved.weightKg!, DateTime.now());
              }
            }
            await _reloadJourney();
            await _reloadDigests();
            updateChart();
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _reloadJourney() async {
    final profile = await widget.observer.getGoalProfile() as DailyTargetProfile;
    var logs = JourneyMath.sortedLogs(
      (await widget.observer.getWeightLogs() as List).cast<WeightEntry>(),
    );
    if (profile.mode == TargetMode.calculated &&
        profile.weightKg != null &&
        logs.isEmpty) {
      await widget.observer.logWeight(profile.weightKg!, DateTime.now());
      logs = JourneyMath.sortedLogs(
        (await widget.observer.getWeightLogs() as List).cast<WeightEntry>(),
      );
    }
    final tracked = Set<String>.from(await widget.observer.getTrackedDateKeys() as Iterable);
    final latest = logs.isNotEmpty ? logs.last.weightKg : profile.weightKg;
    final result = JourneyMath.projection(profile, currentWeight: latest);

    if (result != null && result.targetKcal != kcalBudget) {
      kcalBudget = result.targetKcal;
      await widget.observer.setKcalBudget(kcalBudget);
    }

    if (!mounted) return;
    setState(() {
      journey = WeightSnapshot(
        profile: latest == null ? profile : profile.copyWith(weightKg: latest),
        result: result,
        logs: logs,
        trackedDateKeys: tracked,
      );
    });
  }

  Future<void> _showWeightLog() async {
    final current = journey?.currentKg ?? journey?.profile.weightKg ?? 72;
    final s = S.of(context);
    await showAppDialog(
      context: context,
      child: AppDialogCard(
        icon: Icons.monitor_weight_rounded,
        title: s.logWeightTitle,
        subtitle: journey?.profile.mode == TargetMode.manual
            ? s.logWeightSubtitleManual
            : s.logWeightSubtitle,
        child: WeightLogForm(
          initialKg: current,
          date: selectedDate,
          onSave: (kg) async {
            kcalBudget = await widget.observer.logWeight(kg, selectedDate);
            await _reloadJourney();
            await _reloadDigests();
            updateChart();
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _checkAppUpdate() async {
    try {
      final status = await AppUpdate.status();
      if (!mounted) return;
      setState(() => _updateStatus = status);
      final found = status.newer;
      if (found == null || !AppUpdate.isSupported) return;
      if (await AppUpdate.isSkipped(found)) return;
      if (await AppUpdate.shouldPrompt(found) && mounted) {
        await AppUpdate.markPrompted(found);
        if (mounted) {
          await showUpdateDialog(context: context, release: found);
        }
      }
    } catch (_) {}
  }

  Future<void> _checkForUpdate() async {
    try {
      final status = await AppUpdate.status();
      if (!mounted) return;
      setState(() => _updateStatus = status);
      if (status.newer != null && AppUpdate.isSupported) {
        await showUpdateDialog(context: context, release: status.newer!);
        return;
      }
      await showAppMessage(
        context: context,
        icon: status.hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded,
        title: status.hasUpdate
            ? S.of(context).updateAvailable
            : S.of(context).updateUpToDate,
        subtitle: status.hasUpdate
            ? S.of(context).updateAvailableSubtitle(status.newer!.versionName)
            : S.of(context).currentVersion(status.installed.versionName),
      );
    } catch (_) {
      if (!mounted) return;
      await showAppMessage(
        context: context,
        icon: Icons.error_outline_rounded,
        title: S.of(context).updateFailed,
      );
    }
  }

  Future<void> _refreshGeminiUnlock() async {
    final unlocked = await NutritionApiKeys.hasGemini();
    if (!mounted) return;
    setState(() => _hasGemini = unlocked);
  }

  Future<void> _afterRestore() async {
    sharedPreferences = await SharedPreferences.getInstance();
    selectedDate = DateTime.now();
    currentDaysItems = await widget.observer.getDaysItems(selectedDate);
    kcalBudget = await widget.observer.getKcalBudget();
    if (mounted) {
      setState(() {
        _newestMealsFirst =
            sharedPreferences!.getBool(CalorieSummaryScreenModel.mealSortNewestPref) ?? true;
      });
    }
    await _reloadJourney();
    await _reloadDigests();
    await _refreshGeminiUnlock();
    updateChart();
    final langName = sharedPreferences?.getString('appLang');
    if (langName != null && mounted) {
      final next = AppLang.values.asNameMap()[langName];
      if (next != null) await LocaleScope.of(context).setLang(next);
    }
  }

  Future<void> _showBackup() async {
    final s = S.of(context);
    final counts = await widget.observer.backupCounts() as BackupCounts;
    final record = await widget.observer.backupRecord() as BackupRecord;
    if (!mounted) return;
    final restored = await showAppDialog<BackupSnapshot>(
      context: context,
      child: AppDialogCard(
        icon: Icons.cloud_rounded,
        title: s.backupTitle,
        subtitle: s.backupSubtitle,
        child: BackupForm(
          counts: counts,
          record: record,
          createBackup: ({required includePhotos}) async {
            return await widget.observer.createBackup(includePhotos: includePhotos)
                as BackupSnapshot;
          },
          markSaved: (snapshot, bytes) async {
            await widget.observer.markBackupSaved(snapshot, bytes);
          },
          restoreBackup: (snapshot) async {
            await widget.observer.restoreBackup(snapshot);
          },
          onIncludePhotosChanged: (include) async {
            await widget.observer.setBackupIncludePhotos(include);
          },
          onRestored: _afterRestore,
        ),
      ),
    );
    if (restored != null && mounted) {
      await showAppMessage(
        context: context,
        icon: Icons.cloud_download_rounded,
        title: S.of(context).backupRestored,
        subtitle: S.of(context).backupRestoredSubtitle(restored.mealCount),
      );
    }
  }

  Future<void> _showApiKeys() async {
    final s = S.of(context);
    await showAppDialog(
      context: context,
      child: AppDialogCard(
        icon: Icons.key_rounded,
        title: s.photoEstimate,
        subtitle: s.photoEstimateSubtitle,
        child: ApiKeysForm(
          onSaved: () async {
            Navigator.pop(context);
            await _refreshGeminiUnlock();
          },
        ),
      ),
    );
  }

  void _showAddFood({
    bool serving = false,
    int index = 0,
    bool snap = false,
    FavoriteMeal? draft,
    Uint8List? draftImage,
  }) {
    final s = S.of(context);
    showAppDialog(
      context: context,
      child: AppDialogCard(
        icon: snap
            ? Icons.photo_camera_rounded
            : serving
                ? Icons.add_circle_outline_rounded
                : Icons.restaurant_rounded,
        title: snap ? s.snapAPlate : (serving ? s.anotherServing : s.logAMeal),
        subtitle: snap
            ? s.lookingAtThePlate
            : serving
                ? s.anotherServingSubtitle
                : draft != null
                    ? s.logFavoriteSubtitle
                    : s.logAMealSubtitle,
        child: AddFoodAlertBody(
          startWithCamera: snap,
          addServingMode: serving,
          initialName: draft?.name,
          initialKcalPer100g: draft?.kcalPer100g,
          initialGrams: draft?.weightInGrams,
          initialImage: draftImage,
          initialEstimate: draft == null
              ? null
              : MealEstimate.decodeForGrams(draft.breakdown, draft.weightInGrams),
          initialDescription: draft?.description,
          quickMeals: serving ? const [] : _quickMeals,
          estimateUnlocked: _hasGemini,
          onUnlockEstimate: serving ? null : _showApiKeys,
          loadPhotoForQuick: serving ? null : _latestPhotoForName,
          kcalPer100gOverride: serving ? currentDaysItems[index]["kcalPer100g"] : null,
          onAddFood: (draft) async {
            final before = totalKcalConsumed;
            if (serving) {
              currentDaysItems[index]["weightInGrams"] += (await widget.observer.addFood(
                draft.kcalPer100g,
                draft.weightInGrams,
                selectedDate,
                draft.imageBytes,
                draft.didTakeImage,
                id: currentDaysItems[index]["id"],
                name: draft.name,
                proteinG: draft.proteinG,
              ))["weightInGrams"];
            } else {
              currentDaysItems.add(await widget.observer.addFood(
                draft.kcalPer100g,
                draft.weightInGrams,
                selectedDate,
                draft.imageBytes,
                draft.didTakeImage,
                name: draft.name,
                proteinG: draft.proteinG,
                pinFavorite: draft.pinFavorite,
                breakdown: draft.breakdown,
                description: draft.description,
              ));
            }
            if (mounted) Navigator.pop(context);
            await _afterMealChange(before);
          },
        ),
      ),
    );
  }

  void _showEditFood(int index) {
    final s = S.of(context);
    final item = currentDaysItems[index];
    final grams = (item['weightInGrams'] as num).toInt();
    final photos = (item['mealImages'] ?? []) as List;
    final firstPhoto = photos.isEmpty
        ? null
        : photos.first is Map
            ? Map<String, dynamic>.from(photos.first as Map)
            : null;
    final estimate = MealEstimate.decodeForGrams(item['breakdown'] as String?, grams);
    showAppDialog(
      context: context,
      child: AppDialogCard(
        icon: Icons.edit_rounded,
        title: s.editMeal,
        subtitle: s.editMealSubtitle,
        child: AddFoodAlertBody(
          editMode: true,
          initialName: (item['name'] as String?) ?? '',
          initialKcalPer100g: (item['kcalPer100g'] as num).toInt(),
          initialGrams: grams,
          initialImage: decodeMealImageBytes(firstPhoto),
          initialEstimate: estimate,
          initialDescription: (item['description'] as String?) ?? '',
          estimateUnlocked: _hasGemini,
          onUnlockEstimate: _showApiKeys,
          onAddFood: (draft) async {
            final before = totalKcalConsumed;
            currentDaysItems[index] = await widget.observer.updateFood(
              id: item['id'],
              kcalPer100g: draft.kcalPer100g,
              weightInGrams: draft.weightInGrams,
              imageBytes: draft.imageBytes,
              didTakeImage: draft.didTakeImage,
              name: draft.name,
              proteinG: draft.proteinG,
              pinFavorite: draft.pinFavorite,
              breakdown: draft.breakdown,
              description: draft.description,
            );
            if (mounted) Navigator.pop(context);
            await _afterMealChange(before);
          },
        ),
      ),
    );
  }

  Future<void> _longPressQuick(FavoriteMeal meal) async {
    if (favorites.any((fav) => fav.id == meal.id)) {
      await _removeFavorite(meal);
      return;
    }
    await widget.observer.upsertFavorite(
      name: meal.name,
      kcalPer100g: meal.kcalPer100g,
      weightInGrams: meal.weightInGrams,
      proteinG: meal.proteinG,
      breakdown: meal.breakdown,
      description: meal.description,
    );
    await _reloadDigests();
  }

  Future<void> _openFavorite(FavoriteMeal fav) async {
    if (!fav.canLogAgain) return;
    HapticFeedback.selectionClick();
    final image = await _latestPhotoForName(fav);
    if (!mounted) return;
    _showAddFood(draft: fav, draftImage: image);
  }

  Future<Uint8List?> _latestPhotoForName(FavoriteMeal fav) async {
    MealPhoto? match;
    for (final photo in weekPhotos) {
      if (photo.name.trim().toLowerCase() != fav.name.trim().toLowerCase()) {
        continue;
      }
      match = photo;
      break;
    }
    if (match == null) {
      final photos =
          (await widget.observer.getRecentMealPhotos() as List).cast<MealPhoto>();
      if (mounted) weekPhotos = photos;
      for (final photo in photos) {
        if (photo.name.trim().toLowerCase() != fav.name.trim().toLowerCase()) {
          continue;
        }
        match = photo;
        break;
      }
    }
    if (match == null) return null;
    return loadMealImageBytes(path: match.imagePath, bytes: match.imageBytes);
  }

  Future<void> _pinItem(Map item) async {
    final name = ((item["name"] as String?) ?? '').trim();
    if (name.isEmpty) return;
    FavoriteMeal? existing;
    for (final fav in favorites) {
      if (fav.name.toLowerCase() == name.toLowerCase()) {
        existing = fav;
        break;
      }
    }
    if (existing != null) {
      await widget.observer.deleteFavorite(existing.id);
      await _reloadDigests();
      return;
    }
    await widget.observer.upsertFavorite(
      name: name,
      kcalPer100g: (item["kcalPer100g"] as num).toInt(),
      weightInGrams: (item["weightInGrams"] as num).toInt(),
      proteinG: (item["proteinG"] as num?)?.toDouble() ??
          ProteinMath.estimateGrams(
            name: name,
            kcal: (item["kcalPer100g"] as num) * (item["weightInGrams"] as num) / 100,
          ),
      breakdown: item['breakdown'] as String?,
      description: item['description'] as String?,
    );
    await _reloadDigests();
  }

  Future<void> _removeFavorite(FavoriteMeal fav) async {
    final s = S.of(context);
    final ok = await showAppConfirm(
      context: context,
      title: s.removeFavorite,
      subtitle: s.removeFavoriteSubtitle,
      confirmLabel: s.remove,
    );
    if (!ok) return;
    await widget.observer.deleteFavorite(fav.id);
    await _reloadDigests();
  }

  Future<void> _confirmDelete(int index) async {
    final s = S.of(context);
    final ok = await showAppConfirm(
      context: context,
      title: s.removeMealTitle,
      subtitle: s.removeMealSubtitle,
      confirmLabel: s.remove,
    );
    if (!ok) return;
    final before = totalKcalConsumed;
    widget.observer.deleteItem(currentDaysItems[index]["id"]);
    currentDaysItems.removeAt(index);
    await _afterMealChange(before);
  }

  @override
  void initState() {
    super.initState();
    asyncTaks() async {
      totalKcalConsumed = widget.observer.calcTotalKcalConsumed(currentDaysItems);
      currentDaysItems = await widget.observer.getDaysItems(selectedDate);
      widget.observer.getKcalBudget().then((value) {
        kcalBudget = value;
        updateChart();
        setState(() {});
      });

      setState(() {});
      sharedPreferences = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _newestMealsFirst =
              sharedPreferences!.getBool(CalorieSummaryScreenModel.mealSortNewestPref) ?? true;
        });
      }
      if ((sharedPreferences!.getBool("hasSetCalorieBudget") ?? true) && mounted) {
        await Future.delayed(const Duration(milliseconds: 280));
        if (mounted) await _showWelcome(firstRun: true);
      } else if (mounted) {
        await _reloadJourney();
      }
      if (mounted) await _reloadDigests();
      if (mounted) await _refreshGeminiUnlock();
      await widget.observer.syncHomeWidget();
      if (mounted) await HomeWidgetSync.listen(_onWidgetAction);
      if (mounted) await _checkAppUpdate();
    }
    asyncTaks();
  }

  ({String? path, Uint8List? bytes}) _thumbFor(dynamic photo) {
    if (photo is! Map) return (path: null, bytes: null);
    final row = Map<String, dynamic>.from(photo);
    final path = row['imagePath'] as String?;
    if (path != null && path.isNotEmpty) return (path: path, bytes: null);
    return (path: null, bytes: decodeMealImageBytes(row));
  }

  @override
  void dispose() {
    _ringFocus.dispose();
    HomeWidgetSync.stop();
    super.dispose();
  }

  Future<void> _onWidgetAction(HomeWidgetAction action) async {
    if (!mounted) return;
    selectedDate = DateTime.now();
    currentDaysItems = await widget.observer.getDaysItems(selectedDate);
    updateChart();
    if (!mounted) return;
    if (action.isAdd) {
      _showAddFood();
      return;
    }
    if (!action.isFavorite) return;
    final favs = (await widget.observer.getFavorites() as List).cast<FavoriteMeal>();
    FavoriteMeal? match;
    for (final fav in favs) {
      if (fav.id == action.favoriteId) {
        match = fav;
        break;
      }
    }
    if (match == null || !mounted) return;
    await _openFavorite(match);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ringMeals = [
      for (final item in currentDaysItems)
        RingMeal(
          name: (item['name'] as String?) ?? '',
          kcal: ((item['kcalPer100g'] as num) * (item['weightInGrams'] as num)) / 100.0,
          loggedAt: item['loggedAt'] is num
              ? DateTime.fromMillisecondsSinceEpoch((item['loggedAt'] as num).toInt())
              : null,
          photoPath: () {
            final photos = (item['mealImages'] ?? []) as List;
            if (photos.isEmpty) return null;
            return _thumbFor(photos.first).path;
          }(),
          photoBytes: () {
            final photos = (item['mealImages'] ?? []) as List;
            if (photos.isEmpty) return null;
            return _thumbFor(photos.first).bytes;
          }(),
        ),
    ];
    final mealKcals = [for (final meal in ringMeals) meal.kcal];
    final mealOffsets = <double>[];
    var preceding = 0.0;
    for (final kcal in mealKcals) {
      mealOffsets.add(preceding);
      preceding += kcal;
    }
    final mealOrder = CalorieSummaryScreenModel.mealDisplayOrder(
      currentDaysItems,
      newestFirst: _newestMealsFirst,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.voidBg,
        body: Stack(
          children: [
            const _Atmosphere(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.greeting(DateTime.now().hour),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.prettyDate(selectedDate),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showWelcome,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$kcalBudget kcal',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                if (journey?.visible == true &&
                                    journey!.result != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    s.weekLine(
                                      journey!.journeyGoal,
                                      journey!.journeyPaceKgPerWeek,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.accentSoft,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SettingsMenuButton(
                          onBackup: _showBackup,
                          onApiKeys: _showApiKeys,
                          onCheckUpdate: _checkForUpdate,
                          updateStatus: _updateStatus,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: CalorieCalendar(
                      selectedDate: selectedDate,
                      kcalBudget: kcalBudget,
                      digests: dayDigests,
                      onDateSelected: _selectDate,
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      cacheExtent: 320,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RelativeDayChip(date: selectedDate),
                                const SizedBox(height: 10),
                                FittedBox(
                                  child: ValueListenableBuilder<int?>(
                                    valueListenable: _ringFocus,
                                    builder: (context, focus, _) {
                                      return CalorieRing(
                                        consumed: totalKcalConsumed,
                                        budget: kcalBudget,
                                        ghostConsumed: _yesterdayKcal,
                                        celebrate: _celebrate,
                                        meals: ringMeals,
                                        focus: focus,
                                        onFocus: _setRingFocus,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.mealsHeading(selectedDate),
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ),
                                    Text(
                                      '${currentDaysItems.length}',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.accentSoft,
                                          ),
                                    ),
                                  ],
                                ),
                                if (currentDaysItems.length > 1) ...[
                                  const SizedBox(height: 8),
                                  MealSortToggle(
                                    newestFirst: _newestMealsFirst,
                                    onChanged: _setMealSortNewest,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (currentDaysItems.isEmpty)
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height: 140,
                              child: ClipRect(child: MealsEmptyState()),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index.isOdd) return const SizedBox(height: 10);
                                  final itemIndex = mealOrder[index ~/ 2];
                                  final item = currentDaysItems[itemIndex];
                                  final grams = (item["weightInGrams"] as num).toInt();
                                  final per100 = (item["kcalPer100g"] as num).toInt();
                                  final kcal = grams * per100 / 100;
                                  final photos = (item["mealImages"] ?? []) as List;
                                  final thumb = photos.isEmpty ? (path: null, bytes: null) : _thumbFor(photos.first);
                                  final name = (item["name"] as String?) ?? '';
                                  final stamp = item['loggedAt'];
                                  final loggedAt = stamp is num
                                      ? DateTime.fromMillisecondsSinceEpoch(stamp.toInt())
                                      : null;
                                  final pinned = favorites.any(
                                    (fav) => fav.name.toLowerCase() == name.trim().toLowerCase(),
                                  );
                                  return ValueListenableBuilder<int?>(
                                    valueListenable: _ringFocus,
                                    builder: (context, focus, _) {
                                      return MealCard(
                                    key: ValueKey(item['id']),
                                    name: name,
                                    description: (item['description'] as String?) ?? '',
                                    kcal: kcal.toDouble(),
                                    grams: grams,
                                    kcalPer100g: per100,
                                    dailyBudget: kcalBudget,
                                    precedingKcal: mealOffsets[itemIndex],
                                    loggedAt: loggedAt,
                                    swatch: AppColors.mealSwatch(itemIndex),
                                    selected: focus == itemIndex,
                                    hasPhotos: photos.isNotEmpty,
                                    photoPath: thumb.path,
                                    photoBytes: thumb.bytes,
                                    pinned: pinned,
                                    onPin: name.trim().isEmpty ? null : () => _pinItem(item),
                                    onEdit: () => _showEditFood(itemIndex),
                                    onAddServing: () => _showAddFood(serving: true, index: itemIndex),
                                    onDelete: () => _confirmDelete(itemIndex),
                                    onOpenGallery: () {
                                      showDialog(
                                        context: context,
                                        barrierColor: Colors.transparent,
                                        builder: (context) {
                                          return GalleryAlertBody(imagePaths: photos);
                                        },
                                      );
                                    },
                                      );
                                    },
                                  );
                                },
                                childCount: currentDaysItems.length * 2 - 1,
                              ),
                            ),
                          ),
                        if (_quickMeals.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: FavoriteMealsStrip(
                                favorites: _quickMeals,
                                hasPinned: favorites.isNotEmpty,
                                pinnedIds: favorites.map((fav) => fav.id).toSet(),
                                onLog: _openFavorite,
                                onRemove: _longPressQuick,
                              ),
                            ),
                          ),
                        if (_isToday)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: RestOfDayCoach(
                                consumed: totalKcalConsumed,
                                budget: kcalBudget,
                                favorites: favorites,
                                recent: recentMeals,
                                meals: _todayBites,
                                weightKg: journey?.currentKg ?? journey?.profile.weightKg,
                                isToday: true,
                                onLogFavorite: _openFavorite,
                                onAdd: () => _showAddFood(),
                              ),
                            ),
                          ),
                        if (weekPhotos.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: MealPhotoFeed(photos: weekPhotos),
                            ),
                          ),
                        if (journey?.visible != true)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withOpacity(0.88),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.stroke),
                                ),
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                                child: TrackedDaysStrip(
                                  trackedDateKeys: dayDigests.keys.toSet(),
                                  digests: dayDigests,
                                  kcalBudget: kcalBudget,
                                ),
                              ),
                            ),
                          ),
                        if (journey?.visible == true)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: WeightJourneyCard(
                                snapshot: journey!,
                                onLogWeight: _showWeightLog,
                                digests: dayDigests,
                                kcalBudget: kcalBudget,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 108)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SnapFab(onPressed: () => _showAddFood(snap: true)),
            const SizedBox(width: 12),
            _ModernAddButton(
              onPressed: () => _showAddFood(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(color: AppColors.voidBg),
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E4C8C).withOpacity(0.38),
                    AppColors.voidBg.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 210,
            left: 80,
            right: 80,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentSoft.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapFab extends StatefulWidget {
  final VoidCallback onPressed;

  const _SnapFab({required this.onPressed});

  @override
  State<_SnapFab> createState() => _SnapFabState();
}

class _SnapFabState extends State<_SnapFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.of(context).snapAPlate,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.strokeStrong),
              boxShadow: AppColors.glow(AppColors.accent, 0.12),
            ),
            child: const Icon(
              Icons.photo_camera_rounded,
              color: AppColors.accentSoft,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernAddButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ModernAddButton({required this.onPressed});

  @override
  State<_ModernAddButton> createState() => _ModernAddButtonState();
}

class _ModernAddButtonState extends State<_ModernAddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.of(context).addFood,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: AppColors.gradient,
              boxShadow: AppColors.glow(),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}
