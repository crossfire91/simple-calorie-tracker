import 'package:flutter/material.dart';

class AppColors {
  static const voidBg = Color(0xFF07080C);
  static const voidMid = Color(0xFF0C1018);
  static const surface = Color(0xFF141A24);
  static const surfaceHigh = Color(0xFF1B2330);
  static const surfaceInput = Color(0xFF121821);

  static const stroke = Color(0x1FFFFFFF);
  static const strokeStrong = Color(0x33FFFFFF);

  static const text = Color(0xFFF4F7FB);
  static const textMuted = Color(0xFF9AA6B8);
  static const textFaint = Color(0xFF6D788A);

  static const accent = Color(0xFF2F80ED);
  static const accentSoft = Color(0xFF5BB8FF);
  static const accentDeep = Color(0xFF1B6FE3);

  static const coral = Color(0xFFFF7A6E);
  static const coralSoft = Color(0xFFFF9B8A);

  static const rose = Color(0xFFE2556F);
  static const roseDeep = Color(0xFFC43B55);

  static const mint = Color(0xFF5EE0C2);

  static const mealSwatches = [
    accentSoft,
    mint,
    Color(0xFF7B8CFF),
    Color(0xFFFFC46B),
    Color(0xFFFF8FB3),
    accent,
    Color(0xFFB28DFF),
    Color(0xFF4FD2FF),
  ];

  static Color mealSwatch(int index) => mealSwatches[index % mealSwatches.length];

  static const overlay = Color(0xF205060A);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentSoft, accent, accentDeep],
  );

  static const dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7B8A), rose, roseDeep],
  );

  static List<BoxShadow> glow([Color color = accent, double strength = 0.42]) => [
        BoxShadow(
          color: color.withOpacity(strength),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: accentSoft.withOpacity(strength * 0.45),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static BoxDecoration glass({double radius = 24}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      );
}
