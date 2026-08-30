import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final Widget? suffixIcon;
  final IconData? icon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.suffixIcon,
    this.icon,
    this.keyboardType = TextInputType.number,
    this.onChanged,
    this.obscureText = false,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus = FocusNode()..addListener(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.obscureText ? 1 : widget.maxLines;
    final focused = _focus.hasFocus;

    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focused ? AppColors.accentSoft : AppColors.stroke,
            width: focused ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: AppColors.textMuted, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: widget.keyboardType,
                obscureText: widget.obscureText,
                minLines: lines,
                maxLines: lines,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: widget.textInputAction,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: AppColors.accentSoft,
                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  floatingLabelBehavior: widget.suffix == null
                      ? FloatingLabelBehavior.auto
                      : FloatingLabelBehavior.always,
                  suffixText: widget.suffix,
                  suffixStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  suffixIcon: widget.suffixIcon,
                  suffixIconConstraints: widget.suffixIcon == null
                      ? null
                      : const BoxConstraints(minWidth: 36, minHeight: 36),
                  labelStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  hintStyle: const TextStyle(color: AppColors.textFaint),
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
