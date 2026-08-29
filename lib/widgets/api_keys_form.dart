import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/nutrition/api_keys.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/update/app_update.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';
import 'package:simple_calorie_tracker/widgets/app_text_field.dart';
import 'package:simple_calorie_tracker/widgets/update_banner.dart';

class ApiKeysForm extends StatefulWidget {
  final VoidCallback onSaved;

  const ApiKeysForm({super.key, required this.onSaved});

  @override
  State<ApiKeysForm> createState() => _ApiKeysFormState();
}

class _ApiKeysFormState extends State<ApiKeysForm> {
  final geminiController = TextEditingController();
  final usdaController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    geminiController.text = await NutritionApiKeys.gemini();
    final usda = await NutritionApiKeys.usda();
    usdaController.text = usda == 'DEMO_KEY' ? '' : usda;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    geminiController.dispose();
    usdaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await NutritionApiKeys.save(
      geminiKey: geminiController.text,
      usdaKey: usdaController.text,
    );
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.accentSoft)),
      );
    }

    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: geminiController,
          label: s.geminiKey,
          hint: s.geminiKeyHint,
          icon: Icons.key_rounded,
          keyboardType: TextInputType.text,
          obscureText: true,
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: usdaController,
          label: s.usdaKey,
          hint: s.usdaKeyHint,
          icon: Icons.science_outlined,
          keyboardType: TextInputType.text,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        Text(
          s.keysHelp,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 18),
        AppPrimaryButton(
          label: s.saveKeys,
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
        if (AppUpdate.isSupported) ...[
          const SizedBox(height: 22),
          const UpdateSettingsTile(),
        ],
      ],
    );
  }
}
