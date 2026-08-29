import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/habit/protein.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/nutrition/models.dart';
import 'package:simple_calorie_tracker/nutrition/photo_calorie_service.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_text_field.dart';

class AddFoodAlertBody extends StatefulWidget {
  final Future<void> Function(MealDraft draft) onAddFood;
  final bool addServingMode;
  final int? kcalPer100gOverride;
  final bool startWithCamera;
  final String? initialName;

  const AddFoodAlertBody({
    super.key,
    required this.onAddFood,
    this.addServingMode = false,
    this.kcalPer100gOverride,
    this.startWithCamera = false,
    this.initialName,
  });

  @override
  State<AddFoodAlertBody> createState() => _AddFoodAlertBodyState();
}

class _AddFoodAlertBodyState extends State<AddFoodAlertBody> {
  TextEditingController kcalPer100gController = TextEditingController();
  TextEditingController foodWeightInGrams = TextEditingController();
  final noteController = TextEditingController();
  Uint8List? imageOfFood;
  String? _error;
  String? _status;
  bool _analyzing = false;
  MealEstimate? _estimate;
  bool _pinFavorite = false;
  final _photoCalories = PhotoCalorieService();

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      noteController.text = widget.initialName!;
    }
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera);
        }
      });
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
      _estimate = null;
      _error = null;
      _status = null;
      setState(() {});
    } catch (_) {
      setState(() => _error = S.of(context).couldNotOpenPhoto);
    }
  }

  Future<void> _estimateMeal() async {
    final bytes = imageOfFood;
    final hasPhoto = bytes != null && bytes.isNotEmpty;
    final note = noteController.text.trim();
    if (!hasPhoto && note.isEmpty) {
      setState(() => _error = S.of(context).estimateNeedsInput);
      return;
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
            )
          : await _photoCalories.estimateFromNote(
              note,
              knownGrams: _knownGrams,
            );
      if (!mounted) return;
      _applyEstimate(estimate);
    } catch (error) {
      if (!mounted) return;
      _estimate = null;
      _error = S.of(context).lookupError(error.toString());
      _status = null;
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  int? get _knownGrams {
    final value = int.tryParse(foodWeightInGrams.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _applyEstimate(MealEstimate estimate) {
    _estimate = estimate;
    if (_knownGrams == null && estimate.totalGrams > 0) {
      foodWeightInGrams.text = estimate.totalGrams.toString();
    }
    if (!widget.addServingMode) {
      if (estimate.items.isNotEmpty) {
        kcalPer100gController.text = estimate.kcalPer100g.toString();
      }
    }
    if (noteController.text.trim().isEmpty) {
      noteController.text = estimate.mealName;
    }
    final s = S.of(context);
    if (estimate.items.isEmpty) {
      _status = null;
      _error = estimate.unmatched.isEmpty
          ? s.nothingToLookUp
          : s.noMatchFor(estimate.unmatched.join(', '));
    } else if (estimate.unmatched.isEmpty) {
      _status = '${estimate.mealName} · ${estimate.sourcesLabel}';
      _error = estimate.hasWebSource ? s.webFallbackNote : null;
    } else {
      _status = '${estimate.mealName} · ${estimate.sourcesLabel}';
      _error = s.noMatchEnergyOnly(estimate.unmatched.join(', '));
    }
  }

  @override
  void dispose() {
    kcalPer100gController.dispose();
    foodWeightInGrams.dispose();
    noteController.dispose();
    super.dispose();
  }

  int? get _plateKcal {
    final grams = int.tryParse(foodWeightInGrams.text.trim());
    final per100 = widget.kcalPer100gOverride ??
        int.tryParse(kcalPer100gController.text.trim());
    if (grams == null || grams <= 0 || per100 == null || per100 <= 0) return null;
    return ((per100 * grams) / 100).round();
  }

  void _submit() {
    if (foodWeightInGrams.text.trim().isEmpty ||
        (!widget.addServingMode && kcalPer100gController.text.trim().isEmpty)) {
      setState(() => _error = S.of(context).weightAndEnergy);
      return;
    }
    setState(() => _error = null);

    final per100 = widget.kcalPer100gOverride ??
        int.parse(kcalPer100gController.text);
    final grams = int.parse(foodWeightInGrams.text);
    final name = noteController.text.trim().isEmpty
        ? (_estimate?.mealName ?? '')
        : noteController.text.trim();
    final kcal = (per100 * grams) / 100;
    widget.onAddFood(
      MealDraft(
        kcalPer100g: per100,
        weightInGrams: grams,
        imageBytes: imageOfFood ?? Uint8List(0),
        didTakeImage: imageOfFood != null,
        name: name,
        proteinG: ProteinMath.estimateGrams(name: name, kcal: kcal),
        pinFavorite: _pinFavorite && name.isNotEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: foodWeightInGrams,
                label: s.weight,
                hint: s.gramsHint,
                icon: Icons.scale_rounded,
              ),
            ),
            if (!widget.addServingMode) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: kcalPer100gController,
                  label: s.energy,
                  hint: s.kcalPer100g,
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
            ],
          ],
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
          _EstimateBreakdown(estimate: _estimate!),
        ],
        if (!widget.addServingMode) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: noteController,
            label: s.whatIsIt,
            hint: s.whatIsItHint,
            icon: Icons.edit_note_rounded,
            keyboardType: TextInputType.text,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_analyzing) _estimateMeal();
            },
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _analyzing ? null : () => _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.strokeStrong),
              image: imageOfFood == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(imageOfFood!),
                      fit: BoxFit.cover,
                    ),
            ),
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
                    children: [
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
                                    _estimate = null;
                                    _status = null;
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
                  label: _analyzing
                      ? s.working
                      : (_estimate == null ? s.estimatePlate : s.reEstimate),
                  onPressed: _analyzing ? null : _estimateMeal,
                ),
              ),
            ],
          ],
        ),
        if (!widget.addServingMode) ...[
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
        const SizedBox(height: 18),
        AppPrimaryButton(
          label: widget.addServingMode
              ? s.addServing
              : (_plateKcal != null ? s.logThisPlate(_plateKcal!) : s.logMeal),
          icon: Icons.check_rounded,
          onPressed: _analyzing ? null : _submit,
        ),
      ],
    );
  }
}

class _EstimateBreakdown extends StatelessWidget {
  final MealEstimate estimate;

  const _EstimateBreakdown({required this.estimate});

  @override
  Widget build(BuildContext context) {
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
          for (final item in estimate.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.detected.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    item.unverified
                        ? '${item.grams}g · ${item.itemKcal} kcal · ${S.of(context).webUnverified}'
                        : '${item.grams}g · ${item.itemKcal} kcal · ${item.sourceLabel}',
                    style: TextStyle(
                      color: item.unverified ? AppColors.coralSoft : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          for (final item in estimate.unmatchedItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.coralSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    S.of(context).gramsNoMatch(item.grams),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              estimate.items.isEmpty
                  ? S.of(context).noMatchWriteSimpler
                  : estimate.hasWebSource
                      ? S.of(context).webFallbackNote
                      : S.of(context).editIfOff(estimate.totalKcal),
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
