import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

Uint8List? decodeMealImageBytes(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return decodeMealImageBytes(raw['imageBlob'] ?? raw['imageBytes']);
  }
  if (raw is Uint8List) return raw.isEmpty ? null : raw;
  if (raw is List<int>) {
    if (raw.isEmpty) return null;
    return Uint8List.fromList(raw);
  }
  if (raw is String && raw.isNotEmpty) {
    try {
      final bytes = base64Decode(raw);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
  return null;
}

Future<Uint8List?> loadMealImageBytes({
  String? path,
  Uint8List? bytes,
}) async {
  if (bytes != null && bytes.isNotEmpty) return bytes;
  if (kIsWeb || path == null || path.isEmpty) return null;
  try {
    final file = File(path);
    if (await file.exists()) return await file.readAsBytes();
  } catch (_) {}
  return null;
}

class MealImage extends StatelessWidget {
  final String? path;
  final Uint8List? bytes;
  final BoxFit fit;
  final Widget? fallback;

  const MealImage({
    super.key,
    this.path,
    this.bytes,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  bool get hasImage {
    if (bytes != null && bytes!.isNotEmpty) return true;
    return !kIsWeb && (path?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback ?? const MealImageFallback(),
      );
    }
    if (!kIsWeb && (path?.isNotEmpty ?? false)) {
      return Image.file(
        File(path!),
        fit: fit,
        errorBuilder: (_, __, ___) => fallback ?? const MealImageFallback(),
      );
    }
    return fallback ?? const MealImageFallback();
  }
}

class MealImageFallback extends StatelessWidget {
  const MealImageFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceHigh,
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: AppColors.accentSoft, size: 36),
      ),
    );
  }
}
