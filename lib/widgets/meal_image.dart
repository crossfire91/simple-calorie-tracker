import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

final _decodedMealImages = LinkedHashMap<int, Uint8List>();
const _decodedMealImageCap = 40;

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
    final key = Object.hash(raw.length, raw.hashCode);
    final cached = _decodedMealImages[key];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty) return null;
      if (_decodedMealImages.length >= _decodedMealImageCap) {
        _decodedMealImages.remove(_decodedMealImages.keys.first);
      }
      _decodedMealImages[key] = bytes;
      return bytes;
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
  final int? memCacheWidth;

  const MealImage({
    super.key,
    this.path,
    this.bytes,
    this.fit = BoxFit.cover,
    this.fallback,
    this.memCacheWidth,
  });

  bool get hasImage {
    if (bytes != null && bytes!.isNotEmpty) return true;
    return !kIsWeb && (path?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && (path?.isNotEmpty ?? false)) {
      return Image.file(
        File(path!),
        fit: fit,
        cacheWidth: memCacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => fallback ?? const MealImageFallback(),
      );
    }
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: fit,
        cacheWidth: memCacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
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
