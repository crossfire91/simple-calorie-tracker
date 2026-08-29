import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_calorie_tracker/AddFoodAlertBody/AddFoodAlertBody.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/GalleryAlert/GalleryAlertBody.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/widgets/api_keys_form.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/micro_goals.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';
import 'package:simple_calorie_tracker/habit/streak.dart';
import 'package:simple_calorie_tracker/widgets/calorie_calendar.dart';
import 'package:simple_calorie_tracker/widgets/calorie_ring.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/widgets/daily_target_form.dart';
import 'package:simple_calorie_tracker/widgets/day_pulse_card.dart';
import 'package:simple_calorie_tracker/widgets/favorite_meals_strip.dart';
import 'package:simple_calorie_tracker/widgets/language_chip.dart';
import 'package:simple_calorie_tracker/widgets/loss_support_strip.dart';
import 'package:simple_calorie_tracker/widgets/meal_card.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';
import 'package:simple_calorie_tracker/widgets/meal_photo_feed.dart';
import 'package:simple_calorie_tracker/widgets/rest_of_day_coach.dart';
import 'package:simple_calorie_tracker/widgets/tracked_days_strip.dart';
import 'package:simple_calorie_tracker/widgets/weight_insight.dart';
import 'package:simple_calorie_tracker/widgets/weight_journey_card.dart';
import 'package:simple_calorie_tracker/widgets/weight_log_form.dart';
import 'package:simple_calorie_tracker/platform/home_widget_sync.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';
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
  List<MealPhoto> weekPhotos = [];
  bool _celebrate = false;
  bool _loggingFavorite = false;
  UpdateRelease? _availableUpdate;

  updateChart() {
    totalKcalConsumed = widget.observer.calcTotalKcalConsumed(currentDaysItems);
    setState(() {});
  }

  Future<void> _reloadDigests() async {
    final next = await widget.observer.getDayDigests() as Map<String, DayDigest>;
    final favs = (await widget.observer.getFavorites() as List).cast<FavoriteMeal>();
    final photos = (await widget.observer.getRecentMealPhotos() as List).cast<MealPhoto>();
    if (!mounted) return;
    setState(() {
      dayDigests = next;
      favorites = favs;
      weekPhotos = photos;
    });
  }

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

  int get _streak {
    final meals = StreakMath.mealKeys(dayDigests);
    return StreakMath.currentStreak(meals);
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
    setState(() {});
    currentDaysItems = await widget.observer.getDaysItems(date);
    updateChart();
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
            if (saved.mode == TargetMode.calculated && saved.weightKg != null) {
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
        subtitle: s.logWeightSubtitle,
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
    if (!AppUpdate.isSupported) return;
    try {
      final found = await AppUpdate.check();
      if (found == null || !mounted) return;
      if (await AppUpdate.isSkipped(found)) return;
      if (!mounted) return;
      setState(() => _availableUpdate = found);
      if (await AppUpdate.shouldPrompt(found) && mounted) {
        await AppUpdate.markPrompted(found);
        if (mounted) {
          await showUpdateDialog(context: context, release: found);
        }
      }
    } catch (_) {}
  }

  Future<void> _showUpdate() async {
    final release = _availableUpdate;
    if (release == null) return;
    await showUpdateDialog(context: context, release: release);
  }

  Future<void> _dismissUpdate() async {
    final release = _availableUpdate;
    if (release != null) await AppUpdate.skip(release);
    if (mounted) setState(() => _availableUpdate = null);
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
          onSaved: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showAddFood({bool serving = false, int index = 0, bool snap = false}) {
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
                : s.logAMealSubtitle,
        child: AddFoodAlertBody(
          startWithCamera: snap,
          addServingMode: serving,
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
              ));
            }
            if (mounted) Navigator.pop(context);
            await _afterMealChange(before);
          },
        ),
      ),
    );
  }

  Future<void> _logFavorite(FavoriteMeal fav) async {
    if (_loggingFavorite || fav.weightInGrams <= 0 || fav.kcalPer100g <= 0) return;
    _loggingFavorite = true;
    final before = totalKcalConsumed;
    HapticFeedback.mediumImpact();
    try {
      currentDaysItems.add(await widget.observer.addFood(
        fav.kcalPer100g,
        fav.weightInGrams,
        selectedDate,
        Uint8List(0),
        false,
        name: fav.name,
        proteinG: fav.proteinG,
      ));
      await _afterMealChange(before);
    } finally {
      _loggingFavorite = false;
    }
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
      if ((sharedPreferences!.getBool("hasSetCalorieBudget") ?? true) && mounted) {
        await Future.delayed(const Duration(milliseconds: 280));
        if (mounted) await _showWelcome(firstRun: true);
      } else if (mounted) {
        await _reloadJourney();
      }
      if (mounted) await _reloadDigests();
      await widget.observer.syncHomeWidget();
      if (mounted) await HomeWidgetSync.listen(_onWidgetAction);
      if (mounted) await _checkAppUpdate();
    }
    asyncTaks();
  }

  @override
  void dispose() {
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
    await _logFavorite(match);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

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
                        const LanguageChip(),
                        if (_streak > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.gradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppColors.glow(AppColors.accent, 0.2),
                            ),
                            child: Text(
                              '$_streak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: _showApiKeys,
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.stroke),
                            ),
                            child: const Icon(Icons.key_rounded, size: 18, color: AppColors.textMuted),
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
                                if (journey?.visible == true && journey!.result != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    s.weekLine(
                                      journey!.profile.goal,
                                      journey!.result!.plannedKgPerWeek,
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
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 4),
                            child: Column(
                              children: [
                                if (_availableUpdate != null)
                                  UpdateBanner(
                                    release: _availableUpdate!,
                                    onUpdate: _showUpdate,
                                    onDismiss: _dismissUpdate,
                                  ),
                                FittedBox(
                                  child: CalorieRing(
                                    consumed: totalKcalConsumed,
                                    budget: kcalBudget,
                                    ghostConsumed: _yesterdayKcal,
                                    celebrate: _celebrate,
                                  ),
                                ),
                                if (journey?.visible == true &&
                                    journey!.result != null &&
                                    journey!.currentKg != null) ...[
                                  const SizedBox(height: 8),
                                  WeightInsightBanner(
                                    result: journey!.result!,
                                    goal: journey!.profile.goal,
                                    currentKg: journey!.currentKg!,
                                    onTap: _showWeightLog,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!_isFuture)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: DayPulseCard(
                                snapshot: MicroGoalMath.fromMeals(
                                  _todayBites,
                                  weightKg: journey?.currentKg ?? journey?.profile.weightKg,
                                  forDay: selectedDate,
                                ),
                                title: _isToday ? s.microGoals : s.microGoalsThatDay,
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
                                meals: _todayBites,
                                weightKg: journey?.currentKg ?? journey?.profile.weightKg,
                                isToday: true,
                                onLogFavorite: _logFavorite,
                                onAdd: () => _showAddFood(),
                              ),
                            ),
                          ),
                        if (favorites.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: FavoriteMealsStrip(
                                favorites: favorites,
                                onLog: _logFavorite,
                                onRemove: _removeFavorite,
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
                        if (journey?.showLossSupport == true)
                          const SliverPadding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: LossSupportStrip(),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Text(
                                  s.mealsHeading(selectedDate),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const Spacer(),
                                Text(
                                  '${currentDaysItems.length}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.accentSoft,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (currentDaysItems.isEmpty)
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height: 180,
                              child: ClipRect(child: MealsEmptyState()),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 108),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index.isOdd) return const SizedBox(height: 10);
                                  final itemIndex = index ~/ 2;
                                  final item = currentDaysItems[itemIndex];
                                  final grams = (item["weightInGrams"] as num).toInt();
                                  final per100 = (item["kcalPer100g"] as num).toInt();
                                  final kcal = grams * per100 / 100;
                                  final photos = (item["mealImages"] ?? []) as List;
                                  final firstPhoto = photos.isEmpty
                                      ? null
                                      : photos.first is Map
                                          ? Map<String, dynamic>.from(photos.first as Map)
                                          : null;
                                  final name = (item["name"] as String?) ?? '';
                                  final pinned = favorites.any(
                                    (fav) => fav.name.toLowerCase() == name.trim().toLowerCase(),
                                  );
                                  return MealCard(
                                    name: name,
                                    kcal: kcal.toDouble(),
                                    grams: grams,
                                    kcalPer100g: per100,
                                    hasPhotos: photos.isNotEmpty,
                                    photoPath: firstPhoto?['imagePath'] as String?,
                                    photoBytes: decodeMealImageBytes(firstPhoto),
                                    pinned: pinned,
                                    onPin: name.trim().isEmpty ? null : () => _pinItem(item),
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
                                childCount: currentDaysItems.length * 2 - 1,
                              ),
                            ),
                          ),
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
