import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/nutrition/api_keys.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/clarify.dart';
import 'package:simple_calorie_tracker/nutrition/meal_title.dart';
import 'package:simple_calorie_tracker/nutrition/photo_calorie_service.dart';
import 'package:simple_calorie_tracker/nutrition/text_meal_parser.dart';
import 'package:simple_calorie_tracker/nutrition/voice_note_recorder.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_text_field.dart';

class AddFoodAlertBody extends StatefulWidget {
  final Future<void> Function(MealDraft draft) onAddFood;
  final bool addServingMode;
  final bool editMode;
  final int? kcalPer100gOverride;
  final bool startWithCamera;
  final String? initialName;
  final int? initialKcalPer100g;
  final int? initialGrams;
  final Uint8List? initialImage;
  final MealEstimate? initialEstimate;
  final String? initialDescription;
  final List<FavoriteMeal> quickMeals;
  final ValueChanged<FavoriteMeal>? onPickQuick;
  final Future<Uint8List?> Function(FavoriteMeal meal)? loadPhotoForQuick;
  final bool estimateUnlocked;
  final Future<void> Function()? onUnlockEstimate;

  const AddFoodAlertBody({
    super.key,
    required this.onAddFood,
    this.addServingMode = false,
    this.editMode = false,
    this.kcalPer100gOverride,
    this.startWithCamera = false,
    this.initialName,
    this.initialKcalPer100g,
    this.initialGrams,
    this.initialImage,
    this.initialEstimate,
    this.initialDescription,
    this.quickMeals = const [],
    this.onPickQuick,
    this.loadPhotoForQuick,
    this.estimateUnlocked = false,
    this.onUnlockEstimate,
  });

  @override
  State<AddFoodAlertBody> createState() => _AddFoodAlertBodyState();
}

class _AddFoodAlertBodyState extends State<AddFoodAlertBody> {
  TextEditingController kcalPer100gController = TextEditingController();
  TextEditingController foodWeightInGrams = TextEditingController();
  final _totalKcalController = TextEditingController();
  final noteController = TextEditingController();
  Uint8List? imageOfFood;
  String? _error;
  String? _status;
  bool _analyzing = false;
  MealEstimate? _estimate;
  bool _pinFavorite = false;
  bool _estimateUnlocked = false;
  bool _clarificationUsed = false;
  String? _clarificationNote;
  int _estimateRevision = 0;
  bool _listening = false;
  bool _imageChanged = false;
  bool _manualMenu = false;
  bool _totalKcalMode = false;
  String? _originalNote;
  bool _showOriginal = false;
  final _photoCalories = PhotoCalorieService();
  final _voice = VoiceNoteRecorder();
  final _fieldsTick = ValueNotifier<int>(0);
  final _liveEstimate = ValueNotifier<MealEstimate?>(null);

  @override
  void initState() {
    super.initState();
    _estimateUnlocked = widget.estimateUnlocked;
    _applyDraft(
      name: widget.initialName,
      kcalPer100g: widget.initialKcalPer100g,
      grams: widget.initialGrams,
      image: widget.initialImage,
    );
    noteController.addListener(_tickFields);
    foodWeightInGrams.addListener(_tickFields);
    kcalPer100gController.addListener(_tickFields);
    _totalKcalController.addListener(_tickFields);
    final savedNote = widget.initialDescription?.trim();
    if (savedNote != null && savedNote.isNotEmpty) {
      _originalNote = savedNote;
    }
    if (widget.initialEstimate != null) {
      _estimate = widget.initialEstimate!.copyWith(clearClarification: true);
      _liveEstimate.value = _estimate;
      _clarificationUsed = true;
    }
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera);
        }
      });
    }
  }

  @override
  void didUpdateWidget(AddFoodAlertBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estimateUnlocked != widget.estimateUnlocked) {
      _estimateUnlocked = widget.estimateUnlocked;
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (file == null) return;
      imageOfFood = await file.readAsBytes();
      _imageChanged = true;
      if (!widget.editMode) {
        _estimate = null;
        _liveEstimate.value = null;
        _manualMenu = false;
        _error = null;
        _status = null;
        _clarificationUsed = false;
        _clarificationNote = null;
      }
      setState(() {});
    } catch (_) {
      setState(() => _error = S.of(context).couldNotOpenPhoto);
    }
  }

  Future<void> _unlockEstimate() async {
    await widget.onUnlockEstimate?.call();
    if (!mounted) return;
    final unlocked = await NutritionApiKeys.hasGemini();
    if (!mounted) return;
    setState(() => _estimateUnlocked = unlocked);
  }

  Future<void> _estimateMeal({bool fresh = true}) async {
    if (!_estimateUnlocked) {
      await _unlockEstimate();
      return;
    }
    final bytes = imageOfFood;
    final hasPhoto = bytes != null && bytes.isNotEmpty;
    final note = _lookupNote;
    if (_listening) {
      await _toggleVoice();
      return;
    }
    if (!hasPhoto && note.isEmpty) {
      setState(() => _error = S.of(context).estimateNeedsInput);
      return;
    }
    if (fresh) {
      _clarificationUsed = false;
      _clarificationNote = null;
    }

    setState(() {
      _analyzing = true;
      _error = null;
      _status = hasPhoto ? S.of(context).readingPlate : S.of(context).lookingThatUp;
    });
    try {
      final estimate = hasPhoto
          ? await _photoCalories.estimateFromPhoto(
              bytes,
              knownGrams: _knownGrams,
              note: note,
              extraContext: _clarificationNote,
            )
          : await _photoCalories.estimateFromNote(
              note,
              knownGrams: _knownGrams,
              extraContext: _clarificationNote,
            );
      if (!mounted) return;
      _manualMenu = false;
      _applyEstimate(estimate);
    } catch (error) {
      if (!mounted) return;
      _estimate = null;
      _liveEstimate.value = null;
      _manualMenu = false;
      _error = S.of(context).lookupError(error.toString());
      _status = null;
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _applyDraft({
    String? name,
    int? kcalPer100g,
    int? grams,
    Uint8List? image,
  }) {
    if (name != null && name.isNotEmpty) {
      noteController.text = name;
    }
    if (kcalPer100g != null && kcalPer100g > 0) {
      kcalPer100gController.text = kcalPer100g.toString();
    }
    if (grams != null && grams > 0) {
      foodWeightInGrams.text = grams.toString();
    }
    if (image != null && image.isNotEmpty) {
      imageOfFood = image;
    }
    _syncTotalFromDensity();
  }

  Future<void> _applyFavorite(FavoriteMeal meal) async {
    _applyDraft(
      name: meal.name,
      kcalPer100g: meal.kcalPer100g,
      grams: meal.weightInGrams,
    );
    _error = null;
    _status = null;
    _clarificationNote = null;
    _showOriginal = false;
    final estimate = MealEstimate.decodeForGrams(meal.breakdown, meal.weightInGrams);
    _estimate = estimate?.copyWith(clearClarification: true);
    _liveEstimate.value = _estimate;
    _manualMenu = false;
    _clarificationUsed = estimate != null;
    if (estimate != null) _estimateRevision++;
    final note = meal.description.trim();
    _originalNote = note.isEmpty ? null : note;
    widget.onPickQuick?.call(meal);
    setState(() {});
    final photo = await widget.loadPhotoForQuick?.call(meal);
    if (!mounted || photo == null || photo.isEmpty) return;
    setState(() => imageOfFood = photo);
  }

  String get _lookupNote {
    final typed = noteController.text.trim();
    if (typed.length > mealTitleMaxChars) return typed;
    final original = _originalNote?.trim() ?? '';
    if (original.isNotEmpty) return original;
    return typed;
  }

  void _applyShortTitle(MealEstimate estimate) {
    final source = _lookupNote;
    final title = summarizeMealTitle(
      note: source,
      modelTitle: estimate.mealName,
      itemNames: [
        ...estimate.items.map((item) => item.detected.name),
        ...estimate.unmatchedItems.map((item) => item.name),
      ],
    );
    final original = originalMealNote(note: source, title: title);
    if (original != null) {
      _originalNote = original;
      noteController.text = title;
    } else if (noteController.text.trim().isEmpty && title.isNotEmpty) {
      noteController.text = title;
    }
  }

  int? get _knownGrams {
    final value = int.tryParse(foodWeightInGrams.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _answerClarification(String option) async {
    final question = _estimate?.clarification;
    if (question == null || _analyzing) return;
    _clarificationUsed = true;
    final local = applyClarification(
      estimate: _estimate!,
      question: question,
      option: option,
      strings: S.of(context),
    );
    if (local != null) {
      _applyEstimate(local);
      setState(() {});
      return;
    }
    _clarificationNote = '${question.question} → $option';
    await _estimateMeal(fresh: false);
  }

  void _skipClarification() {
    setState(() {
      _clarificationUsed = true;
      _estimate = _estimate?.copyWith(clearClarification: true);
      _liveEstimate.value = _estimate;
    });
  }

  void _applyEstimate(MealEstimate estimate) {
    final clarification = suggestClarification(
      note: _lookupNote,
      estimate: estimate,
      strings: S.of(context),
      fromModel: estimate.clarification,
      alreadyAnswered: _clarificationUsed,
    );
    _estimateRevision++;
    _estimate = estimate.copyWith(
      clarification: clarification,
      clearClarification: clarification == null,
    );
    _liveEstimate.value = _estimate;
    _syncTotalsFromEstimate(_estimate!, fillGramsIfEmpty: true);
    _applyShortTitle(estimate);
    final s = S.of(context);
    if (estimate.items.isEmpty) {
      _status = null;
      _error = estimate.unmatched.isEmpty
          ? s.nothingToLookUp
          : s.noMatchFor(estimate.unmatched.join(', '));
    } else if (estimate.unmatched.isEmpty) {
      _status = estimate.mealName;
      _error = null;
    } else {
      _status = estimate.mealName;
      _error = s.noMatchEnergyOnly(estimate.unmatched.join(', '));
    }
  }

  void _tickFields() {
    _fieldsTick.value++;
  }

  bool get _canReset => !widget.addServingMode && !widget.editMode;

  bool get _isDirty {
    return noteController.text.trim().isNotEmpty ||
        foodWeightInGrams.text.trim().isNotEmpty ||
        kcalPer100gController.text.trim().isNotEmpty ||
        _totalKcalController.text.trim().isNotEmpty ||
        imageOfFood != null ||
        _estimate != null ||
        _error != null ||
        _status != null ||
        _pinFavorite ||
        _originalNote != null ||
        _manualMenu ||
        _clarificationNote != null ||
        _listening;
  }

  Future<void> _resetForm() async {
    if (_analyzing || !_canReset) return;
    if (_listening) {
      _listening = false;
      await _voice.cancel();
      if (!mounted) return;
    }
    noteController.clear();
    foodWeightInGrams.clear();
    kcalPer100gController.clear();
    _totalKcalController.clear();
    setState(() {
      imageOfFood = null;
      _error = null;
      _status = null;
      _estimate = null;
      _liveEstimate.value = null;
      _pinFavorite = false;
      _clarificationUsed = false;
      _clarificationNote = null;
      _estimateRevision++;
      _imageChanged = false;
      _manualMenu = false;
      _totalKcalMode = false;
      _originalNote = null;
      _showOriginal = false;
    });
  }

  @override
  void dispose() {
    noteController.removeListener(_tickFields);
    foodWeightInGrams.removeListener(_tickFields);
    kcalPer100gController.removeListener(_tickFields);
    _totalKcalController.removeListener(_tickFields);
    kcalPer100gController.dispose();
    foodWeightInGrams.dispose();
    _totalKcalController.dispose();
    noteController.dispose();
    _fieldsTick.dispose();
    _liveEstimate.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _syncTotalsFromEstimate(MealEstimate estimate, {required bool fillGramsIfEmpty}) {
    if (estimate.totalGrams > 0 && (!fillGramsIfEmpty || _knownGrams == null)) {
      foodWeightInGrams.text = estimate.totalGrams.toString();
    }
    if (!widget.addServingMode && estimate.items.isNotEmpty) {
      kcalPer100gController.text = estimate.kcalPer100g.toString();
    }
    _syncTotalFromDensity();
  }

  void _syncTotalFromDensity() {
    final plate = _densityPlateKcal;
    if (plate != null) {
      _totalKcalController.text = plate.toString();
    }
  }

  int? get _typedTotalKcal {
    final value = int.tryParse(_totalKcalController.text.trim());
    if (value == null || value < 0) return null;
    return value;
  }

  int? get _densityPlateKcal {
    final grams = int.tryParse(foodWeightInGrams.text.trim());
    final per100 = widget.kcalPer100gOverride ??
        int.tryParse(kcalPer100gController.text.trim());
    if (grams == null || grams <= 0 || per100 == null || per100 < 0) return null;
    return ((per100 * grams) / 100).round();
  }

  (int, int)? get _resolvedTotals {
    if (_totalKcalMode) {
      final total = _typedTotalKcal;
      if (total == null) return null;
      final grams = _knownGrams ?? 100;
      return (((total * 100) / grams).round(), grams);
    }
    final grams = int.tryParse(foodWeightInGrams.text.trim());
    final per100 = widget.kcalPer100gOverride ??
        int.tryParse(kcalPer100gController.text.trim());
    if (grams == null || grams <= 0 || per100 == null || per100 < 0) return null;
    return (per100, grams);
  }

  void _toggleTotalKcalMode() {
    setState(() {
      if (_totalKcalMode) {
        final total = _typedTotalKcal;
        final grams = _knownGrams;
        if (total != null && grams != null) {
          kcalPer100gController.text = ((total * 100) / grams).round().toString();
        } else if (total != null) {
          foodWeightInGrams.text = '100';
          kcalPer100gController.text = total.toString();
        }
        _totalKcalMode = false;
      } else {
        final plate = _densityPlateKcal;
        if (plate != null) {
          _totalKcalController.text = plate.toString();
        }
        _totalKcalMode = true;
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (_analyzing) return;
    if (!_estimateUnlocked) {
      await _unlockEstimate();
      if (!_estimateUnlocked) return;
    }
    if (_listening) {
      setState(() {
        _listening = false;
        _analyzing = true;
        _error = null;
        _status = S.of(context).lookingThatUp;
      });
      try {
        final clip = await _voice.stop();
        if (!mounted) return;
        if (clip == null) {
          setState(() {
            _analyzing = false;
            _error = S.of(context).couldNotRecord;
            _status = null;
          });
          return;
        }
        final result = await _photoCalories.estimateFromAudio(
          clip.bytes,
          mimeType: clip.mimeType,
          knownGrams: _knownGrams,
          extraContext: _clarificationNote,
        );
        if (!mounted) return;
        if (result.transcript.isNotEmpty) {
          noteController.text = result.transcript;
        }
        _manualMenu = false;
        _applyEstimate(result.estimate);
      } catch (error) {
        if (!mounted) return;
        _estimate = null;
        _liveEstimate.value = null;
        _manualMenu = false;
        _error = S.of(context).lookupError(error.toString());
        _status = null;
      } finally {
        if (mounted) setState(() => _analyzing = false);
      }
      return;
    }

    try {
      final started = await _voice.start();
      if (!mounted) return;
      if (!started) {
        setState(() => _error = S.of(context).couldNotRecord);
        return;
      }
      setState(() {
        _listening = true;
        _error = null;
        _status = S.of(context).listening;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = S.of(context).couldNotRecord);
    }
  }

  void _openManualMenu() {
    final note = _lookupNote;
    final seeded = splitMealNote(note);
    final items = seeded.isEmpty
        ? [
            DetectedFood(
              name: note.isEmpty ? 'Item' : note,
              queryEn: note,
              grams: _knownGrams ?? 100,
            ),
          ]
        : seeded;
    _manualMenu = true;
    _applyEstimate(
      MealEstimate(
        mealName: noteController.text.trim().isNotEmpty ? noteController.text.trim() : items.first.name,
        unmatchedItems: items,
      ),
    );
    setState(() {});
  }

  Future<void> _lookupMenu() async {
    final estimate = _estimate;
    if (estimate == null || _analyzing) return;
    final items = estimate.menuItems;
    if (items.isEmpty) return;
    setState(() {
      _analyzing = true;
      _error = null;
      _status = S.of(context).lookingThatUp;
    });
    try {
      final next = await _photoCalories.groundItems(
        mealName: estimate.mealName,
        items: items,
        knownGrams: _knownGrams,
      );
      if (!mounted) return;
      _applyEstimate(next);
    } catch (error) {
      if (!mounted) return;
      _error = S.of(context).lookupError(error.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _onEstimateEdited(MealEstimate next) {
    final structureChanged = next.items.length != _estimate!.items.length ||
        next.unmatchedItems.length != _estimate!.unmatchedItems.length;
    if (structureChanged) _estimateRevision++;
    _estimate = next;
    _syncTotalsFromEstimate(next, fillGramsIfEmpty: false);
    var chromeChanged = false;
    if (next.items.isNotEmpty) {
      final nextError =
          next.unmatched.isEmpty ? null : S.of(context).noMatchEnergyOnly(next.unmatched.join(', '));
      chromeChanged = nextError != _error || next.mealName != _status;
      _error = nextError;
      _status = next.mealName;
    }
    _liveEstimate.value = next;
    _fieldsTick.value++;
    if (chromeChanged || structureChanged) setState(() {});
  }

  int? get _plateKcal {
    if (_totalKcalMode) return _typedTotalKcal;
    return _densityPlateKcal;
  }

  void _submit() {
    final totals = _resolvedTotals;
    if (totals == null) {
      setState(() => _error = _totalKcalMode
          ? S.of(context).enterCaloriesFirst
          : S.of(context).weightAndEnergy);
      return;
    }
    setState(() => _error = null);

    final per100 = totals.$1;
    final grams = totals.$2;
    final typed = noteController.text.trim();
    final source = _lookupNote;
    final title = typed.isNotEmpty && typed.length <= mealTitleMaxChars
        ? typed
        : summarizeMealTitle(
            note: source,
            modelTitle: _estimate?.mealName,
            itemNames: [
              ...?_estimate?.items.map((item) => item.detected.name),
              ...?_estimate?.unmatchedItems.map((item) => item.name),
            ],
          );
    final name = title.isNotEmpty ? title : typed;
    final original = originalMealNote(note: source, title: name);
    final kcal = (per100 * grams) / 100;
    widget.onAddFood(
      MealDraft(
        kcalPer100g: per100,
        weightInGrams: grams,
        imageBytes: imageOfFood ?? Uint8List(0),
        didTakeImage: _imageChanged && imageOfFood != null,
        name: name,
        proteinG: ProteinMath.estimateGrams(name: name, kcal: kcal),
        pinFavorite: _pinFavorite && name.isNotEmpty,
        breakdown: _estimate?.encode(),
        description: original,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.addServingMode && !widget.editMode && widget.quickMeals.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.quickMeals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final meal = widget.quickMeals[index];
                return GestureDetector(
                  onTap: () => _applyFavorite(meal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Text(
                      meal.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.addServingMode) ...[
          AppTextField(
            controller: noteController,
            label: _originalNote == null ? s.whatIsIt : s.mealTitle,
            hint: _originalNote == null ? s.whatIsItHint : s.mealTitleHint,
            icon: Icons.edit_note_rounded,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              tooltip: _listening ? s.listeningShort : s.whatIsIt,
              onPressed: _analyzing ? null : _toggleVoice,
              icon: Icon(
                _listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                color: _listening ? AppColors.coral : AppColors.accentSoft,
              ),
            ),
          ),
          if (_originalNote != null) ...[
            const SizedBox(height: 8),
            _OriginalNoteFold(
              label: s.originalNote,
              text: _originalNote!,
              open: _showOriginal,
              onToggle: () => setState(() => _showOriginal = !_showOriginal),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (!widget.addServingMode && _estimate == null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _analyzing ? null : _openManualMenu,
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: Text(s.buildMenu),
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: foodWeightInGrams,
                label: s.weight,
                suffix: s.gramsHint,
                icon: Icons.scale_rounded,
              ),
            ),
            if (!widget.addServingMode) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: _totalKcalMode ? _totalKcalController : kcalPer100gController,
                  label: _totalKcalMode ? s.totalEnergy : s.energy,
                  suffix: _totalKcalMode ? s.kcalHint : s.kcalPer100g,
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
            ],
          ],
        ),
        if (!widget.addServingMode)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('total-kcal-mode'),
              onPressed: _analyzing ? null : _toggleTotalKcalMode,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textFaint,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                minimumSize: Size.zero,
              ),
              child: Text(
                _totalKcalMode ? s.orKcalPer100g : s.orTotalKcal,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (_status != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _status!,
              style: const TextStyle(color: AppColors.mint, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.coralSoft, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (_estimate != null) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<MealEstimate?>(
            valueListenable: _liveEstimate,
            builder: (context, estimate, _) {
              final live = estimate ?? _estimate!;
              return _EstimateBreakdown(
                estimate: live,
                revision: _estimateRevision,
                enabled: !_analyzing,
                manual: _manualMenu,
                onChanged: _onEstimateEdited,
                onLookup: _lookupMenu,
                onAdd: () => _onEstimateEdited(live.addUnmatched()),
              );
            },
          ),
          if (_estimate!.clarification != null) ...[
            const SizedBox(height: 10),
            _ClarificationCard(
              question: _estimate!.clarification!,
              busy: _analyzing,
              skipLabel: s.looksFine,
              onPick: _answerClarification,
              onSkip: _skipClarification,
            ),
          ],
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _analyzing ? null : () => _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera),
          child: RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.strokeStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageOfFood == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_camera_outlined, color: AppColors.accentSoft, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        s.addAPhoto,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.photoStaysLocal,
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        imageOfFood!,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      ),
                      if (_analyzing)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.accentSoft),
                          ),
                        ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: GestureDetector(
                          onTap: _analyzing
                              ? null
                              : () => setState(() {
                                    imageOfFood = null;
                                    _imageChanged = true;
                                    if (!widget.editMode) {
                                      _estimate = null;
                                      _liveEstimate.value = null;
                                      _manualMenu = false;
                                      _status = null;
                                      _clarificationUsed = false;
                                      _clarificationNote = null;
                                    }
                                  }),
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s.removePhoto,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _analyzing ? s.estimating : s.retake,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppGhostButton(
                label: s.gallery,
                onPressed: _analyzing ? null : () => _pick(ImageSource.gallery),
              ),
            ),
            if (!widget.addServingMode) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppGhostButton(
                  accent: true,
                  icon: _estimate == null ? Icons.auto_awesome_rounded : Icons.refresh_rounded,
                  label: !_estimateUnlocked
                      ? s.unlockEstimate
                      : _analyzing
                          ? s.working
                          : (_estimate == null ? s.estimatePlate : s.reEstimate),
                  onPressed: _analyzing
                      ? null
                      : (_estimateUnlocked ? () => _estimateMeal() : _unlockEstimate),
                ),
              ),
            ],
          ],
        ),
        if (!widget.addServingMode && !widget.editMode) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _pinFavorite = !_pinFavorite),
            child: Row(
              children: [
                Icon(
                  _pinFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 18,
                  color: _pinFavorite ? AppColors.mint : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.saveAsFavorite,
                    style: TextStyle(
                      color: _pinFavorite ? AppColors.mint : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ValueListenableBuilder<int>(
          valueListenable: _fieldsTick,
          builder: (context, _, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canReset && _isDirty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('reset-meal'),
                      onPressed: _analyzing ? null : _resetForm,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(s.resetMeal),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                AppPrimaryButton(
                  label: widget.addServingMode
                      ? s.addServing
                      : widget.editMode
                          ? (_plateKcal != null ? s.saveThisPlate(_plateKcal!) : s.saveChanges)
                          : (_plateKcal != null ? s.logThisPlate(_plateKcal!) : s.logMeal),
                  icon: Icons.check_rounded,
                  onPressed: _analyzing ? null : _submit,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OriginalNoteFold extends StatelessWidget {
  final String label;
  final String text;
  final bool open;
  final VoidCallback onToggle;

  const _OriginalNoteFold({
    required this.label,
    required this.text,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClarificationCard extends StatelessWidget {
  final ClarificationQuestion question;
  final bool busy;
  final String skipLabel;
  final ValueChanged<String> onPick;
  final VoidCallback onSkip;

  const _ClarificationCard({
    required this.question,
    required this.busy,
    required this.skipLabel,
    required this.onPick,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.strokeStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in question.options)
                GestureDetector(
                  onTap: busy ? null : () => onPick(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.strokeStrong),
                    ),
                    child: Text(
                      option,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: busy ? null : onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Text(
                    skipLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstimateBreakdown extends StatefulWidget {
  final MealEstimate estimate;
  final int revision;
  final bool enabled;
  final bool manual;
  final ValueChanged<MealEstimate> onChanged;
  final VoidCallback? onLookup;
  final VoidCallback? onAdd;

  const _EstimateBreakdown({
    required this.estimate,
    required this.revision,
    required this.enabled,
    required this.manual,
    required this.onChanged,
    this.onLookup,
    this.onAdd,
  });

  @override
  State<_EstimateBreakdown> createState() => _EstimateBreakdownState();
}

class _EstimateBreakdownState extends State<_EstimateBreakdown> {
  final _grams = <TextEditingController>[];
  final _kcals = <TextEditingController>[];
  final _names = <TextEditingController>[];

  MealEstimate get estimate => widget.estimate;

  @override
  void initState() {
    super.initState();
    _rebuildControllers();
  }

  @override
  void didUpdateWidget(covariant _EstimateBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _rebuildControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in [..._grams, ..._kcals, ..._names]) {
      controller.dispose();
    }
    _grams.clear();
    _kcals.clear();
    _names.clear();
  }

  void _rebuildControllers() {
    _disposeControllers();
    for (final item in estimate.items) {
      _names.add(TextEditingController(text: item.detected.name));
      _grams.add(TextEditingController(text: item.grams.toString()));
      _kcals.add(TextEditingController(text: item.kcalPer100g.toString()));
    }
    for (final item in estimate.unmatchedItems) {
      _names.add(TextEditingController(text: item.name));
      _grams.add(TextEditingController(text: item.grams.toString()));
      _kcals.add(TextEditingController(text: '0'));
    }
  }

  void _editName(int index, {required bool unmatched}) {
    final name = _names[index].text.trim();
    if (name.isEmpty) return;
    final local = unmatched ? index - estimate.items.length : index;
    widget.onChanged(estimate.renameMenuLine(local, name, unmatched: unmatched));
  }

  void _editGrams(int index, {required bool unmatched}) {
    final grams = int.tryParse(_grams[index].text.trim());
    if (grams == null || grams <= 0) return;
    final local = unmatched ? index - estimate.items.length : index;
    widget.onChanged(
      unmatched
          ? estimate.replaceUnmatched(local, grams: grams)
          : estimate.replaceGrounded(local, grams: grams),
    );
  }

  void _editKcalPer100g(int index, {required bool unmatched}) {
    final per100 = int.tryParse(_kcals[index].text.trim());
    if (per100 == null || per100 < 0) return;
    final local = unmatched ? index - estimate.items.length : index;
    widget.onChanged(
      unmatched
          ? estimate.replaceUnmatched(local, kcalPer100g: per100)
          : estimate.replaceGrounded(local, kcalPer100g: per100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: [
          if (widget.manual) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.menuHint,
                style: const TextStyle(color: AppColors.textFaint, fontSize: 11, height: 1.3),
              ),
            ),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < estimate.items.length; i++)
            widget.manual
                ? _manualLine(
                    name: _names[i],
                    itemKcal: estimate.items[i].itemKcal,
                    missing: false,
                    grams: _grams[i],
                    kcal: _kcals[i],
                    enabled: widget.enabled,
                    onName: () => _editName(i, unmatched: false),
                    onGrams: () => _editGrams(i, unmatched: false),
                    onKcal: () => _editKcalPer100g(i, unmatched: false),
                    onRemove: () => widget.onChanged(estimate.removeMenuLine(i, unmatched: false)),
                  )
                : _estimateLine(
                    name: estimate.items[i].detected.name,
                    itemKcal: estimate.items[i].itemKcal,
                    missing: false,
                    grams: _grams[i],
                    kcal: _kcals[i],
                    enabled: widget.enabled,
                    onGrams: () => _editGrams(i, unmatched: false),
                    onKcal: () => _editKcalPer100g(i, unmatched: false),
                  ),
          for (var i = 0; i < estimate.unmatchedItems.length; i++)
            widget.manual
                ? _manualLine(
                    name: _names[estimate.items.length + i],
                    itemKcal: 0,
                    missing: true,
                    grams: _grams[estimate.items.length + i],
                    kcal: _kcals[estimate.items.length + i],
                    enabled: widget.enabled,
                    onName: () => _editName(estimate.items.length + i, unmatched: true),
                    onGrams: () => _editGrams(estimate.items.length + i, unmatched: true),
                    onKcal: () => _editKcalPer100g(estimate.items.length + i, unmatched: true),
                    onRemove: () => widget.onChanged(estimate.removeMenuLine(i, unmatched: true)),
                  )
                : _estimateLine(
                    name: estimate.unmatchedItems[i].name,
                    itemKcal: 0,
                    missing: true,
                    grams: _grams[estimate.items.length + i],
                    kcal: _kcals[estimate.items.length + i],
                    enabled: widget.enabled,
                    onGrams: () => _editGrams(estimate.items.length + i, unmatched: true),
                    onKcal: () => _editKcalPer100g(estimate.items.length + i, unmatched: true),
                  ),
          if (!widget.manual) const SizedBox(height: 8),
          if (widget.manual) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.onAdd != null)
                  TextButton.icon(
                    onPressed: widget.enabled ? widget.onAdd : null,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.addIngredient),
                  ),
                if (widget.onLookup != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.enabled ? widget.onLookup : null,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(s.lookUpMenu),
                  ),
                ],
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              estimate.items.isEmpty ? s.noMatchWriteSimpler : s.editIfOff(estimate.totalKcal),
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateLine({
    required String name,
    required int itemKcal,
    required bool missing,
    required TextEditingController grams,
    required TextEditingController kcal,
    required bool enabled,
    required VoidCallback onGrams,
    required VoidCallback onKcal,
  }) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            missing ? s.noMatchShort : '$itemKcal kcal',
            style: TextStyle(
              color: missing ? AppColors.textMuted : AppColors.mint,
              fontSize: missing ? 12 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          _MiniField(controller: grams, suffix: 'g', enabled: enabled, onChanged: (_) => onGrams()),
          const SizedBox(width: 6),
          _MiniField(controller: kcal, suffix: '/100g', enabled: enabled, onChanged: (_) => onKcal()),
        ],
      ),
    );
  }

  Widget _manualLine({
    required TextEditingController name,
    required int itemKcal,
    required bool missing,
    required TextEditingController grams,
    required TextEditingController kcal,
    required bool enabled,
    required VoidCallback onName,
    required VoidCallback onGrams,
    required VoidCallback onKcal,
    required VoidCallback onRemove,
  }) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _MiniField(
                  controller: name,
                  hint: s.itemName,
                  enabled: enabled,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.left,
                  onChanged: (_) => onName(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      missing ? s.noMatchShort : '$itemKcal kcal',
                      style: TextStyle(
                        color: missing ? AppColors.textMuted : AppColors.mint,
                        fontSize: missing ? 12 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    _MiniField(controller: grams, suffix: 'g', enabled: enabled, onChanged: (_) => onGrams()),
                    const SizedBox(width: 6),
                    _MiniField(controller: kcal, suffix: '/100g', enabled: enabled, onChanged: (_) => onKcal()),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AppColors.textFaint,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String? suffix;
  final String? hint;
  final bool enabled;
  final TextInputType keyboardType;
  final TextAlign textAlign;
  final ValueChanged<String> onChanged;

  const _MiniField({
    required this.controller,
    this.suffix,
    this.hint,
    required this.enabled,
    this.keyboardType = TextInputType.number,
    this.textAlign = TextAlign.right,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final boxed = suffix != null;
    return SizedBox(
      width: boxed ? (suffix == '/100g' ? 86 : 68) : null,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textAlign: textAlign,
        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          suffixText: suffix,
          suffixStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: AppColors.surfaceInput,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentSoft, width: 1.2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.stroke),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
