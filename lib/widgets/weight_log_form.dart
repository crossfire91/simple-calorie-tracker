import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_text_field.dart';
import 'package:simple_calorie_tracker/widgets/fine_slider.dart';

class WeightLogForm extends StatefulWidget {
  final double initialKg;
  final DateTime date;
  final void Function(double kg) onSave;

  const WeightLogForm({
    super.key,
    required this.initialKg,
    required this.date,
    required this.onSave,
  });

  @override
  State<WeightLogForm> createState() => _WeightLogFormState();
}

class _WeightLogFormState extends State<WeightLogForm> {
  late double kg;
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    kg = widget.initialKg.clamp(40, 180);
    controller = TextEditingController(text: kg.toStringAsFixed(1));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.accentSoft,
        inactiveTrackColor: const Color(0xFF243044),
        thumbColor: Colors.white,
        overlayColor: AppColors.accentSoft.withOpacity(0.16),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.monitor_weight_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                        Expanded(
                      child: Text(
                        S.of(context).onDate(widget.date),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${kg.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                FineSlider(
                  min: 40,
                  max: 180,
                  value: kg,
                  step: 0.1,
                  onChanged: (v) {
                    setState(() {
                      kg = (v * 10).round() / 10;
                      controller.text = kg.toStringAsFixed(1);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: controller,
            label: S.of(context).orTypeIt,
            suffix: 'kg',
            icon: Icons.edit_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (text) {
              final parsed = double.tryParse(text.replaceAll(',', '.').trim());
              if (parsed == null) return;
              setState(() => kg = parsed.clamp(40, 180));
            },
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: S.of(context).saveWeighIn,
            icon: Icons.favorite_rounded,
            onPressed: () => widget.onSave(kg),
          ),
        ],
      ),
    );
  }
}
