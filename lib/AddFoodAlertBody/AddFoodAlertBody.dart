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
  final PhotoCalorieService? photoCalories;

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
    this.photoCalories,
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
  bool _writingFields = false;
  bool _writingKcal = false;
  bool _writingNote = false;
  bool _gramsFromEstimate = false;
  bool _kcalFromEstimate = false;
  bool _menuFromEstimate = false;
  String? _userNote;
  String? _appliedTitle;
  late final PhotoCalorieService _photoCalories;
  final _voice = VoiceNoteRecorder();
  final _fieldsTick = ValueNotifier<int>(0);
  final _liveEstimate = ValueNotifier<MealEstimate?>(null);

  @override
  void initState() {
    super.initState();
    _estimateUnlocked = widget.estimateUnlocked;
    _photoCalories = widget.photoCalories ?? PhotoCalorieService();
    _applyDraft(
      name: widget.initialName,
      kcalPer100g: widget.initialKcalPer100g,
      grams: widget.initialGrams,
      image: widget.initialImage,
    );
    noteController.addListener(_onNoteChanged);
    foodWeightInGrams.addListener(_onWeightChanged);
    kcalPer100gController.addListener(_onKcalChanged);
    _totalKcalController.addListener(_onKcalChanged);
    final savedNote = widget.initialDescription?.trim();
    if (savedNote != null && savedNote.isNotEmpty) {
      _originalNote = savedNote;
      _userNote = savedNote;
    } else {
      final titled = noteController.text.trim();
      if (titled.isNotEmpty) _userNote = titled;
    }
    final titled = noteController.text.trim();
    if (titled.isNotEmpty) _appliedTitle = titled;
    if (widget.initialEstimate != null) {
      _estimate = widget.initialEstimate!.copyWith(clearClarification: true);
      _liveEstimate.value = _estimate;
      _clarificationUsed = true;
      _menuFromEstimate = true;
    } else if (!widget.addServingMode) {
      _openManualMenu(notify: false);
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
      if (!widget.editMode && !_manualMenu) {
        _estimate = null;
        _liveEstimate.value = null;
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
    final descriptionOnly = !_manualMenu || _noteIsOnlyADescription;
    final note = descriptionOnly ? _lookupNote : _estimateNote;
    final wasManual = _manualMenu;
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
      if (_noteWasEdited) {
        _originalNote = null;
        _showOriginal = false;
        _appliedTitle = null;
      }
    }
    final knownGrams = (fresh && _gramsFromEstimate) ? null : _knownGrams;
    final knownKcalPer100g =
        _totalKcalMode || (fresh && _kcalFromEstimate) ? null : _typedKcalPer100g;
    final knownTotalKcal =
        !_totalKcalMode || (fresh && _kcalFromEstimate) ? null : _typedTotalKcal;

    setState(() {
      _analyzing = true;
      _error = null;
      _status = hasPhoto ? S.of(context).readingPlate : S.of(context).lookingThatUp;
      if (fresh) {
        if (_menuFromEstimate && !_manualMenu) {
          _estimate = null;
          _liveEstimate.value = null;
          _manualMenu = false;
          _menuFromEstimate = false;
        }
        if (_gramsFromEstimate) {
          _setWeightText('', fromEstimate: false);
        }
        if (_kcalFromEstimate) {
          _setKcalPer100g('', fromEstimate: false);
          _setTotalKcal('', fromEstimate: false);
        }
      }
    });
    try {
      final extra = fresh ? null : _clarificationNote;
      final estimate = hasPhoto
          ? await _photoCalories.estimateFromPhoto(
              bytes,
              knownGrams: knownGrams,
              knownKcalPer100g: knownKcalPer100g,
              knownTotalKcal: knownTotalKcal,
              note: note,
              extraContext: extra,
              noteIsIngredientList: !descriptionOnly,
            )
          : await _photoCalories.estimateFromNote(
              note,
              knownGrams: knownGrams,
              knownKcalPer100g: knownKcalPer100g,
              knownTotalKcal: knownTotalKcal,
              extraContext: extra,
            );
      if (!mounted) return;
      _manualMenu = wasManual && !descriptionOnly;
      _applyEstimate(estimate);
    } catch (error) {
      if (!mounted) return;
      _manualMenu = wasManual;
      if (!wasManual) {
        _estimate = null;
        _liveEstimate.value = null;
      }
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
      _setNoteText(name, fromUser: true);
    }
    if (kcalPer100g != null && kcalPer100g > 0) {
      _setKcalPer100g(kcalPer100g.toString(), fromEstimate: false);
    }
    if (grams != null && grams > 0) {
      _setWeightText(grams.toString(), fromEstimate: false);
    }
    if (image != null && image.isNotEmpty) {
      imageOfFood = image;
    }
    _syncTotalFromDensity(fromEstimate: false);
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
    _clarificationUsed = estimate != null;
    if (estimate != null) _estimateRevision++;
    final note = meal.description.trim();
    _originalNote = note.isEmpty ? null : note;
    _userNote = note.isEmpty ? meal.name : note;
    _appliedTitle = noteController.text.trim();
    _menuFromEstimate = estimate != null;
    if (estimate == null && !widget.addServingMode) {
      _openManualMenu(notify: false);
    } else {
      _manualMenu = false;
    }
    widget.onPickQuick?.call(meal);
    setState(() {});
    final photo = await widget.loadPhotoForQuick?.call(meal);
    if (!mounted || photo == null || photo.isEmpty) return;
    setState(() => imageOfFood = photo);
  }

  String get _lookupNote {
    final user = _userNote?.trim() ?? '';
    if (user.isNotEmpty) return user;
    return noteForEstimate(
      typed: noteController.text,
      originalNote: _originalNote,
      appliedTitle: _appliedTitle,
    );
  }

  List<DetectedFood> get _listedIngredients {
    return _estimate?.menuItems.where((item) => item.name.trim().isNotEmpty).toList() ??
        const [];
  }

  bool get _noteIsOnlyADescription => mealNoteIsOnlyADescription(
        title: noteController.text,
        ingredientNames: _listedIngredients.map((item) => item.name),
      );

  String get _estimateNote {
    if (_noteIsOnlyADescription) return _lookupNote;
    return formatMealEstimateNote(
      title: noteController.text,
      ingredients: _listedIngredients,
    );
  }

  bool get _noteWasEdited {
    final typed = noteController.text.trim();
    final applied = _appliedTitle?.trim() ?? '';
    return applied.isNotEmpty && typed.isNotEmpty && typed != applied;
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
      _setNoteText(title, fromUser: false);
    } else if (noteController.text.trim().isEmpty && title.isNotEmpty) {
      _setNoteText(title, fromUser: false);
    }
    _appliedTitle = noteController.text.trim();
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

  void _applyEstimate(MealEstimate estimate, {bool fromAi = true}) {
    if (fromAi) _menuFromEstimate = true;
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
    _syncTotalsFromEstimate(_estimate!, fillGramsIfEmpty: !_gramsFromEstimate);
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

  Future<void> _resetForm() async {
    if (_analyzing || !_canReset) return;
    if (_listening) {
      _listening = false;
      await _voice.cancel();
      if (!mounted) return;
    }
    _setNoteText('', fromUser: true);
    _setWeightText('', fromEstimate: false);
    _setKcalPer100g('', fromEstimate: false);
    _setTotalKcal('', fromEstimate: false);
    imageOfFood = null;
    _error = null;
    _status = null;
    _pinFavorite = false;
    _clarificationUsed = false;
    _clarificationNote = null;
    _imageChanged = false;
    _menuFromEstimate = false;
    _userNote = null;
    _appliedTitle = null;
    _totalKcalMode = false;
    _originalNote = null;
    _showOriginal = false;
    _openManualMenu(notify: false, blank: true);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    noteController.removeListener(_onNoteChanged);
    foodWeightInGrams.removeListener(_onWeightChanged);
    kcalPer100gController.removeListener(_onKcalChanged);
    _totalKcalController.removeListener(_onKcalChanged);
    kcalPer100gController.dispose();
    foodWeightInGrams.dispose();
    _totalKcalController.dispose();
    noteController.dispose();
    _fieldsTick.dispose();
    _liveEstimate.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (!_writingNote) {
      _userNote = noteController.text.trim();
      _syncSingleIngredientFromNote();
    }
    _tickFields();
  }

  bool get _singleManualIngredient {
    final estimate = _estimate;
    return _manualMenu && estimate != null && estimate.menuItems.length == 1;
  }

  void _syncSingleIngredientFromNote() {
    if (!_singleManualIngredient) return;
    final estimate = _estimate!;
    final title = noteController.text.trim();
    final current = estimate.menuItems.first.name;
    final linked = current.isEmpty || current == estimate.mealName;
    if (!linked) return;
    var next = current == title
        ? estimate
        : estimate.renameMenuLine(0, title, unmatched: estimate.items.isEmpty);
    if (next.mealName != title) next = next.copyWith(mealName: title);
    if (identical(next, estimate)) return;
    _estimate = next;
    _liveEstimate.value = next;
  }

  void _setNoteText(String text, {required bool fromUser}) {
    _writingNote = true;
    noteController.text = text;
    _writingNote = false;
    if (fromUser) _userNote = text.trim();
  }

  void _onWeightChanged() {
    if (!_writingFields) _gramsFromEstimate = false;
    _tickFields();
  }

  void _onKcalChanged() {
    if (!_writingKcal) _kcalFromEstimate = false;
    _tickFields();
  }

  void _setWeightText(String text, {required bool fromEstimate}) {
    _writingFields = true;
    foodWeightInGrams.text = text;
    _writingFields = false;
    _gramsFromEstimate = fromEstimate && text.trim().isNotEmpty;
  }

  void _setKcalPer100g(String text, {required bool fromEstimate}) {
    _writingKcal = true;
    kcalPer100gController.text = text;
    _writingKcal = false;
    if (!_totalKcalMode) {
      _kcalFromEstimate = fromEstimate && text.trim().isNotEmpty;
    }
  }

  void _setTotalKcal(String text, {required bool fromEstimate}) {
    _writingKcal = true;
    _totalKcalController.text = text;
    _writingKcal = false;
    if (_totalKcalMode) {
      _kcalFromEstimate = fromEstimate && text.trim().isNotEmpty;
    }
  }

  void _syncTotalsFromEstimate(
    MealEstimate estimate, {
    required bool fillGramsIfEmpty,
    bool fromMenuEdit = false,
  }) {
    if (estimate.totalGrams > 0 && (!fillGramsIfEmpty || _knownGrams == null)) {
      _setWeightText(estimate.totalGrams.toString(), fromEstimate: _menuFromEstimate);
    }
    if (!widget.addServingMode &&
        estimate.items.isNotEmpty &&
        (fromMenuEdit || _kcalFromEstimate || _typedKcalPer100g == null)) {
      final density = estimate.kcalPer100g;
      if (density > 0 || _menuFromEstimate) {
        _setKcalPer100g(density.toString(), fromEstimate: _menuFromEstimate);
      }
    }
    if (fromMenuEdit || _kcalFromEstimate || _typedTotalKcal == null) {
      final implied = _impliedTotalKcal(estimate);
      if (implied != null) {
        _setTotalKcal(implied.toString(), fromEstimate: _menuFromEstimate);
      } else {
        _syncTotalFromDensity(fromEstimate: _menuFromEstimate);
      }
    }
  }

  int? _impliedTotalKcal(MealEstimate estimate) {
    if (estimate.totalKcal > 0) return estimate.totalKcal;
    if (_totalKcalMode &&
        estimate.items.length == 1 &&
        estimate.items.single.grams <= 0 &&
        estimate.items.single.kcalPer100g >= 0) {
      return estimate.items.single.kcalPer100g;
    }
    return null;
  }

  void _syncTotalFromDensity({required bool fromEstimate}) {
    final plate = _densityPlateKcal;
    if (plate != null) {
      _setTotalKcal(plate.toString(), fromEstimate: fromEstimate);
    }
  }

  int? get _typedKcalPer100g {
    final value = int.tryParse(kcalPer100gController.text.trim());
    if (value == null || value < 0) return null;
    return value;
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
    final kcalFromEstimate = _kcalFromEstimate;
    setState(() {
      if (_totalKcalMode) {
        final total = _typedTotalKcal;
        final grams = _knownGrams;
        if (total != null && grams != null) {
          _setKcalPer100g(((total * 100) / grams).round().toString(), fromEstimate: kcalFromEstimate);
        } else if (total != null) {
          _setKcalPer100g(total.toString(), fromEstimate: kcalFromEstimate);
        }
        _totalKcalMode = false;
      } else {
        final plate = _densityPlateKcal;
        if (plate != null) {
          _setTotalKcal(plate.toString(), fromEstimate: kcalFromEstimate);
        }
        _totalKcalMode = true;
      }
      if (_manualMenu) _estimateRevision++;
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
          knownGrams: _gramsFromEstimate ? null : _knownGrams,
          knownKcalPer100g: _totalKcalMode || _kcalFromEstimate ? null : _typedKcalPer100g,
          knownTotalKcal: !_totalKcalMode || _kcalFromEstimate ? null : _typedTotalKcal,
          extraContext: _clarificationNote,
        );
        if (!mounted) return;
        if (result.transcript.isNotEmpty) {
          _setNoteText(result.transcript, fromUser: true);
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

  void _openManualMenu({bool notify = true, bool blank = false}) {
    if (blank) {
      _manualMenu = true;
      _menuFromEstimate = false;
      _error = null;
      _status = null;
      _totalKcalMode = false;
      _estimateRevision++;
      const estimate = MealEstimate(
        mealName: '',
        unmatchedItems: [
          DetectedFood(name: '', queryEn: '', grams: 0),
        ],
      );
      _estimate = estimate;
      _liveEstimate.value = estimate;
      if (notify && mounted) setState(() {});
      return;
    }
    final note = _lookupNote;
    final typedName = noteController.text.trim();
    var grams = _knownGrams;
    int? per100 = _totalKcalMode ? null : _typedKcalPer100g;
    if (_totalKcalMode) {
      final total = _typedTotalKcal;
      if (total != null && total > 0) {
        per100 = grams == null || grams <= 0 ? total : ((total * 100) / grams).round();
      }
    }
    final seeded = splitMealNote(note, knownGrams: grams, fallbackGrams: 0);
    final items = seeded.isEmpty
        ? [
            DetectedFood(
              name: typedName,
              queryEn: typedName,
              grams: grams ?? 0,
            ),
          ]
        : seeded;
    var estimate = MealEstimate(
      mealName: typedName.isNotEmpty
          ? typedName
          : (items.first.name.isNotEmpty ? items.first.name : typedName),
      unmatchedItems: items,
    );
    if (per100 != null && per100 > 0 && estimate.unmatchedItems.length == 1) {
      estimate = estimate.replaceUnmatched(
        0,
        grams: grams ?? estimate.unmatchedItems.first.grams,
        kcalPer100g: per100,
      );
    }
    _manualMenu = true;
    _menuFromEstimate = false;
    _error = null;
    _status = null;
    _totalKcalMode = false;
    _estimateRevision++;
    _estimate = estimate;
    _liveEstimate.value = estimate;
    _syncTotalsFromEstimate(estimate, fillGramsIfEmpty: false, fromMenuEdit: true);
    if (notify && mounted) setState(() {});
  }

  void _addIngredient() {
    if (_totalKcalMode) _toggleTotalKcalMode();
    final live = _liveEstimate.value ?? _estimate;
    if (live == null) return;
    _onEstimateEdited(live.addUnmatched());
  }

  Future<void> _lookupMenu() async {
    final estimate = _estimate;
    if (estimate == null || _analyzing) return;
    final items = estimate.menuItems.where((item) => item.name.trim().isNotEmpty).toList();
    if (items.isEmpty) {
      setState(() => _error = S.of(context).nothingToLookUp);
      return;
    }
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
      _applyEstimate(next, fromAi: false);
    } catch (error) {
      if (!mounted) return;
      _error = S.of(context).lookupError(error.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _onEstimateEdited(MealEstimate next) {
    _menuFromEstimate = false;
    if (_manualMenu && next.menuItems.length == 1) {
      final name = next.menuItems.first.name.trim();
      if (name.isNotEmpty && noteController.text.trim() != name) {
        next = next.copyWith(mealName: name);
        _setNoteText(name, fromUser: true);
      } else {
        final title = noteController.text.trim();
        if (title.isNotEmpty && next.mealName != title) {
          next = next.copyWith(mealName: title);
        }
      }
    }
    final structureChanged = next.menuItems.length != _estimate!.menuItems.length;
    if (structureChanged) _estimateRevision++;
    _estimate = next;
    _syncTotalsFromEstimate(next, fillGramsIfEmpty: false, fromMenuEdit: true);
    var chromeChanged = false;
    if (!_manualMenu && next.items.isNotEmpty) {
      final missed = [
        for (final item in next.unmatchedItems)
          if (item.name.trim().isNotEmpty) item.name.trim(),
      ];
      final nextError = missed.isEmpty ? null : S.of(context).noMatchEnergyOnly(missed.join(', '));
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
        if (_canReset || widget.quickMeals.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: Row(
              children: [
                if (_canReset) ...[
                  _ResetChip(onTap: _analyzing ? null : _resetForm),
                  if (widget.quickMeals.isNotEmpty) const SizedBox(width: 8),
                ],
                if (widget.quickMeals.isNotEmpty)
                  Expanded(
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
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.addServingMode) ...[
          AppTextField(
            controller: noteController,
            label: _originalNote == null ? s.whatIsIt : s.mealTitle,
            hint: _originalNote == null ? s.whatIsItHint : s.mealTitleHint,
            icon: Icons.restaurant_menu_rounded,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            prominent: true,
            autofocus: !widget.startWithCamera && !widget.addServingMode,
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
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _manualMenu
              ? const SizedBox(width: double.infinity)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: foodWeightInGrams,
                            label: s.weight,
                            suffix: s.gramsHint,
                            icon: Icons.scale_rounded,
                            scrubMin: 0,
                            scrubMax: 2000,
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
                              scrubMin: 0,
                              scrubMax: _totalKcalMode ? 3000 : 950,
                              scrubStep: _totalKcalMode ? 5 : 1,
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
                  ],
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
                key: ValueKey(_estimateRevision),
                estimate: live,
                revision: _estimateRevision,
                enabled: !_analyzing,
                manual: _manualMenu,
                totalKcalMode: _totalKcalMode,
                onChanged: _onEstimateEdited,
                onLookup: _lookupMenu,
                onAdd: _addIngredient,
                onToggleTotalKcal: _singleManualIngredient ? _toggleTotalKcalMode : null,
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
                                    if (!widget.editMode && !_manualMenu) {
                                      _estimate = null;
                                      _liveEstimate.value = null;
                                      _status = null;
                                      _clarificationUsed = false;
                                      _clarificationNote = null;
                                      _openManualMenu(notify: false);
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            s.photoMayMissIngredients,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 12, height: 1.35),
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
                  key: const Key('estimate-meal'),
                  accent: true,
                  icon: _estimate == null || _manualMenu ? Icons.auto_awesome_rounded : Icons.refresh_rounded,
                  label: !_estimateUnlocked
                      ? s.unlockEstimate
                      : _analyzing
                          ? s.working
                          : (_estimate == null || _manualMenu ? s.estimatePlate : s.reEstimate),
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

class _ResetChip extends StatelessWidget {
  final VoidCallback? onTap;

  const _ResetChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const Key('reset-meal'),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.coralSoft.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.coralSoft),
            const SizedBox(width: 6),
            Text(
              S.of(context).resetMeal,
              style: const TextStyle(
                color: AppColors.coralSoft,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
  final bool totalKcalMode;
  final ValueChanged<MealEstimate> onChanged;
  final VoidCallback? onLookup;
  final VoidCallback? onAdd;
  final VoidCallback? onToggleTotalKcal;

  const _EstimateBreakdown({
    super.key,
    required this.estimate,
    required this.revision,
    required this.enabled,
    required this.manual,
    this.totalKcalMode = false,
    required this.onChanged,
    this.onLookup,
    this.onAdd,
    this.onToggleTotalKcal,
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
    if (oldWidget.revision != widget.revision || oldWidget.totalKcalMode != widget.totalKcalMode) {
      _rebuildControllers();
    } else {
      _syncNameControllers();
    }
  }

  void _syncNameControllers() {
    final items = estimate.menuItems;
    if (_names.length != items.length) return;
    for (var i = 0; i < items.length; i++) {
      final name = items[i].name;
      if (_names[i].text == name) continue;
      _names[i].value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
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
      _grams.add(TextEditingController(text: item.grams > 0 ? item.grams.toString() : ''));
      final energy = widget.totalKcalMode ? item.itemKcal : item.kcalPer100g;
      _kcals.add(
        TextEditingController(
          text: widget.manual && energy == 0 ? '' : energy.toString(),
        ),
      );
    }
    for (final item in estimate.unmatchedItems) {
      _names.add(TextEditingController(text: item.name));
      _grams.add(TextEditingController(text: item.grams > 0 ? item.grams.toString() : ''));
      _kcals.add(TextEditingController(text: ''));
    }
  }

  int? _per100FromField(int index) {
    final typed = int.tryParse(_kcals[index].text.trim());
    if (typed == null || typed < 0) return null;
    if (!widget.totalKcalMode) return typed;
    final grams = int.tryParse(_grams[index].text.trim()) ?? 100;
    if (grams <= 0) return typed;
    return ((typed * 100) / grams).round();
  }

  void _editName(int index, {required bool unmatched}) {
    final name = _names[index].text.trim();
    final local = unmatched ? index - estimate.items.length : index;
    widget.onChanged(estimate.renameMenuLine(local, name, unmatched: unmatched));
  }

  void _editGrams(int index, {required bool unmatched}) {
    final raw = _grams[index].text.trim();
    final grams = raw.isEmpty ? 0 : int.tryParse(raw);
    if (grams == null || grams < 0) return;
    final local = unmatched ? index - estimate.items.length : index;
    final per100 = widget.totalKcalMode ? _per100FromField(index) : null;
    widget.onChanged(
      unmatched
          ? estimate.replaceUnmatched(local, grams: grams, kcalPer100g: per100)
          : estimate.replaceGrounded(local, grams: grams, kcalPer100g: per100),
    );
  }

  void _editKcalPer100g(int index, {required bool unmatched}) {
    final raw = _kcals[index].text.trim();
    if (raw.isEmpty && unmatched) return;
    final per100 = raw.isEmpty ? 0 : _per100FromField(index);
    if (per100 == null) return;
    final local = unmatched ? index - estimate.items.length : index;
    final grams = int.tryParse(_grams[index].text.trim());
    widget.onChanged(
      unmatched
          ? estimate.replaceUnmatched(
              local,
              grams: grams == null || grams < 0 ? 0 : grams,
              kcalPer100g: per100,
            )
          : estimate.replaceGrounded(local, kcalPer100g: per100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lines = Column(
      children: [
        if (widget.manual && estimate.menuItems.length == 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.menuHint,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11, height: 1.3),
            ),
          ),
          const SizedBox(height: 8),
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
        if (widget.manual && widget.onToggleTotalKcal != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('total-kcal-mode'),
              onPressed: widget.enabled ? widget.onToggleTotalKcal : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textFaint,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                minimumSize: Size.zero,
              ),
              child: Text(
                widget.totalKcalMode ? s.orKcalPer100g : s.orTotalKcal,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (!widget.manual) const SizedBox(height: 8),
        if (widget.manual) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (widget.onAdd != null)
                Expanded(
                  child: _AddIngredientRow(
                    label: s.addIngredient,
                    enabled: widget.enabled,
                    onTap: widget.onAdd!,
                  ),
                ),
              if (widget.onAdd != null && widget.onLookup != null) const SizedBox(width: 8),
              if (widget.onLookup != null)
                TextButton.icon(
                  onPressed: widget.enabled ? widget.onLookup : null,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text(s.lookUpMenu),
                ),
            ],
          ),
        ],
        if (!widget.manual)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              estimate.items.isEmpty ? s.noMatchWriteSimpler : s.editIfOff(estimate.totalKcal),
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11, height: 1.3),
            ),
          ),
      ],
    );
    if (widget.manual) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.only(right: 12, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(child: lines),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: lines,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AppTextField(
                          controller: name,
                          label: s.itemName,
                          hint: s.itemNameHint,
                          icon: Icons.restaurant_rounded,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => onName(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: grams,
                                label: s.weight,
                                suffix: s.gramsHint,
                                icon: Icons.scale_rounded,
                                onChanged: (_) => onGrams(),
                                scrubMin: 0,
                                scrubMax: 2000,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppTextField(
                                controller: kcal,
                                label: widget.totalKcalMode ? s.totalEnergy : s.energy,
                                suffix: widget.totalKcalMode ? s.kcalHint : s.kcalPer100g,
                                icon: Icons.local_fire_department_rounded,
                                onChanged: (_) => onKcal(),
                                scrubMin: 0,
                                scrubMax: widget.totalKcalMode ? 3000 : 950,
                                scrubStep: widget.totalKcalMode ? 5 : 1,
                              ),
                            ),
                          ],
                        ),
                        if (!missing) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '$itemKcal kcal',
                                style: const TextStyle(
                                  color: AppColors.mint,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('remove-ingredient'),
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textFaint,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddIngredientRow extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _AddIngredientRow({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.strokeStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.accentSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _MiniField({
    required this.controller,
    required this.suffix,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: suffix == '/100g' ? 86 : 68,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
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
