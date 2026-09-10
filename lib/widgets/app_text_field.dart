import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/fine_slider.dart';

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
  final bool clearable;
  final bool prominent;
  final bool compact;
  final bool autofocus;
  final double? scrubMin;
  final double? scrubMax;
  final double? scrubStep;

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
    this.clearable = true,
    this.prominent = false,
    this.compact = false,
    this.autofocus = false,
    this.scrubMin,
    this.scrubMax,
    this.scrubStep,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (mounted) setState(() {});
    });
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeListener;
  bool _scrubbing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusWhenReady());
    }
  }

  void _focusWhenReady() {
    if (!mounted || !widget.autofocus) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _focus.requestFocus();
      return;
    }
    _routeAnimation = animation;
    _routeListener = (status) {
      if (status != AnimationStatus.completed) return;
      _clearRouteListener();
      if (mounted && widget.autofocus) _focus.requestFocus();
    };
    animation.addStatusListener(_routeListener!);
  }

  void _clearRouteListener() {
    final animation = _routeAnimation;
    final listener = _routeListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _routeAnimation = null;
    _routeListener = null;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _scrubbing = false;
    }
  }

  @override
  void dispose() {
    _clearRouteListener();
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  TextStyle get _suffixStyle => const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  Widget? get _unitSuffix {
    final suffix = widget.suffix;
    if (suffix == null || suffix.isEmpty) return null;
    if (!suffix.contains('/')) {
      return Padding(
        padding: const EdgeInsets.only(left: 2, right: 4),
        child: Text(suffix, style: _suffixStyle),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 4),
      child: SizedBox(
        width: 36,
        child: Text(
          suffix,
          textAlign: TextAlign.right,
          maxLines: 2,
          style: _suffixStyle.copyWith(fontSize: 11, height: 1.15),
        ),
      ),
    );
  }

  Widget? get _trailing {
    final showClear = widget.clearable && widget.controller.text.isNotEmpty;
    final clear = showClear
        ? _FieldClear(
            tooltip: S.of(context).clearField,
            emphasized: _focus.hasFocus,
            onPressed: _clear,
          )
        : null;
    final extras = <Widget>[
      if (clear != null) clear,
      if (widget.suffixIcon != null) widget.suffixIcon!,
    ];
    if (extras.isEmpty) return null;
    if (extras.length == 1) return extras.single;
    return Row(mainAxisSize: MainAxisSize.min, children: extras);
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  bool get _canScrub =>
      widget.scrubMin != null &&
      widget.scrubMax != null &&
      widget.scrubMax! > widget.scrubMin!;

  double get _scrubValue {
    final parsed = double.tryParse(widget.controller.text.trim()) ?? 0;
    return parsed.clamp(widget.scrubMin!, widget.scrubMax!);
  }

  void _toggleScrub() {
    if (!_canScrub) return;
    HapticFeedback.mediumImpact();
    setState(() => _scrubbing = !_scrubbing);
  }

  void _onScrub(double value) {
    final text = value.round().toString();
    if (widget.controller.text == text) return;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.obscureText ? 1 : widget.maxLines;
    final focused = _focus.hasFocus;
    final trailing = _trailing;

    final prominent = widget.prominent;
    final compact = widget.compact;
    final field = GestureDetector(
      onTap: () => _focus.requestFocus(),
      onLongPress: _canScrub ? _toggleScrub : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: prominent
            ? const EdgeInsets.fromLTRB(16, 8, 10, 8)
            : compact
                ? const EdgeInsets.fromLTRB(8, 2, 4, 2)
                : const EdgeInsets.fromLTRB(12, 2, 8, 2),
        decoration: BoxDecoration(
          color: prominent
              ? Color.alphaBlend(
                  AppColors.accentSoft.withValues(alpha: 0.10),
                  AppColors.surfaceHigh,
                )
              : AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(prominent ? 20 : 16),
          border: Border.all(
            color: focused
                ? AppColors.accentSoft
                : prominent
                    ? AppColors.accentSoft.withValues(alpha: 0.32)
                    : AppColors.stroke,
            width: focused || prominent ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              GestureDetector(
                onLongPress: _canScrub ? _toggleScrub : null,
                child: Icon(
                  widget.icon,
                  color: _scrubbing
                      ? AppColors.mint
                      : prominent
                          ? AppColors.accentSoft
                          : AppColors.textMuted,
                  size: prominent
                      ? 22
                      : compact
                          ? 18
                          : 20,
                ),
              ),
              SizedBox(width: prominent ? 10 : compact ? 6 : 8),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
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
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: prominent ? 18 : 16,
                  fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  floatingLabelBehavior: widget.suffix == null
                      ? FloatingLabelBehavior.auto
                      : FloatingLabelBehavior.always,
                  suffixIcon: trailing,
                  suffixIconConstraints: trailing == null
                      ? null
                      : const BoxConstraints(minWidth: 28, minHeight: 32),
                  labelStyle: TextStyle(
                    color: prominent ? AppColors.accentSoft : AppColors.textMuted,
                    fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
                    fontSize: prominent ? 14 : 13,
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
            if (_unitSuffix != null) _unitSuffix!,
          ],
        ),
      ),
    );
    if (!_canScrub) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _scrubbing
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FineSlider(
                    key: const Key('number-scrub'),
                    min: widget.scrubMin!,
                    max: widget.scrubMax!,
                    value: _scrubValue,
                    step: widget.scrubStep ?? 1,
                    onChanged: _onScrub,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FieldClear extends StatelessWidget {
  final String tooltip;
  final bool emphasized;
  final VoidCallback onPressed;

  const _FieldClear({
    required this.tooltip,
    required this.emphasized,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: const Key('clear-field'),
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 4, 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.text.withValues(alpha: emphasized ? 0.16 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 12,
              color: emphasized ? AppColors.textMuted : AppColors.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}
