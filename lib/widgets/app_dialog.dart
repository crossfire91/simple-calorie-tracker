import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/theme/grip_scroll.dart';
import 'package:simple_calorie_tracker/widgets/app_button.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class AppDialogCard extends StatelessWidget {
  final IconData icon;
  final List<Color> iconColors;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showClose;

  const AppDialogCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.iconColors = const [AppColors.accentSoft, AppColors.accentDeep],
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.overlay,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const GripScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: AppColors.glass(radius: 28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: iconColors,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(icon, color: Colors.white, size: 24),
                              ),
                              const Spacer(),
                              if (showClose)
                                _CloseChip(onTap: () => Navigator.pop(context)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                          const SizedBox(height: 22),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const _KeyboardStrut(),
          ],
        ),
      ),
    );
  }
}

class _KeyboardStrut extends StatelessWidget {
  const _KeyboardStrut();

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.viewInsetsOf(context).bottom);
  }
}

class _CloseChip extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.stroke),
        ),
        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
      ),
    );
  }
}

Future<void> showAppMessage({
  required BuildContext context,
  required String title,
  String? subtitle,
  IconData icon = Icons.info_rounded,
}) {
  return showAppDialog(
    context: context,
    child: AppDialogCard(
      icon: icon,
      iconColors: const [AppColors.accentSoft, AppColors.accentDeep],
      title: title,
      subtitle: subtitle,
      child: AppPrimaryButton(
        label: S.of(context).gotIt,
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );
}

Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  String? subtitle,
  String confirmLabel = 'Delete',
  bool danger = true,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    child: AppDialogCard(
      icon: danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
      iconColors: danger
          ? const [Color(0xFFFF7B8A), AppColors.roseDeep]
          : const [AppColors.accentSoft, AppColors.accentDeep],
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          AppPrimaryButton(
            label: confirmLabel,
            danger: danger,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          AppGhostButton(
            label: S.of(context).cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  return result == true;
}
