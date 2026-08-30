import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/habit/favorites.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';

class MealPhotoFeed extends StatefulWidget {
  final List<MealPhoto> photos;
  final ValueChanged<MealPhoto>? onOpen;

  const MealPhotoFeed({
    super.key,
    required this.photos,
    this.onOpen,
  });

  @override
  State<MealPhotoFeed> createState() => _MealPhotoFeedState();
}

class _MealPhotoFeedState extends State<MealPhotoFeed> {
  late final PageController _pages = PageController(viewportFraction: 0.72);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();
    final s = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.weekOnYourPlate, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text(
              s.swipeTheWeek,
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              DateTime? date;
              try {
                date = JourneyMath.parseDateKey(photo.dateKey);
              } catch (_) {}
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: widget.onOpen == null ? null : () => widget.onOpen!(photo),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.strokeStrong),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _PhotoFace(photo: photo),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xE607080C)],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  photo.name.isEmpty ? s.unnamedMeal : photo.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${photo.kcal.toStringAsFixed(0)} kcal'
                                  '${date == null ? '' : ' · ${s.prettyDate(date)}'}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoFace extends StatelessWidget {
  final MealPhoto photo;

  const _PhotoFace({required this.photo});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && photo.imagePath.isNotEmpty) {
      return Image.file(
        File(photo.imagePath),
        fit: BoxFit.cover,
        cacheWidth: 640,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const _PhotoFallback(),
      );
    }
    final bytes = photo.imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: 640,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const _PhotoFallback(),
      );
    }
    return const _PhotoFallback();
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

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
