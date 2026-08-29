import 'dart:io';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/l10n/strings.dart';
import 'package:simple_calorie_tracker/theme/app_colors.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';

class GalleryAlertBody extends StatefulWidget {
  List? imagePaths = [];

  GalleryAlertBody({@required this.imagePaths});

  @override
  State<GalleryAlertBody> createState() => _GalleryAlertBodyState();
}

class _GalleryAlertBodyState extends State<GalleryAlertBody> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final images = widget.imagePaths ?? [];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Material(
        color: AppColors.overlay,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: images.isEmpty
                    ? Text(S.of(context).noPhotos, style: const TextStyle(color: AppColors.textMuted))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            S.of(context).mealGallery,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            images.length == 1
                                ? S.of(context).onePhoto
                                : S.of(context).photoOf(_index, images.length),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 22),
                          CarouselSlider(
                            options: CarouselOptions(
                              height: width * 0.82,
                              enableInfiniteScroll: false,
                              enlargeCenterPage: true,
                              viewportFraction: 0.86,
                              onPageChanged: (i, _) => setState(() => _index = i),
                            ),
                            items: List.generate(images.length, (int index) {
                              final row = images[index] is Map
                                  ? Map<String, dynamic>.from(images[index] as Map)
                                  : <String, dynamic>{};
                              final path = (row['imagePath'] as String?) ?? '';
                              final bytes = decodeMealImageBytes(row);
                              return GestureDetector(
                                onTap: () {
                                  if (bytes != null && bytes.isNotEmpty) {
                                    showImageViewer(context, MemoryImage(bytes));
                                    return;
                                  }
                                  if (!kIsWeb && path.isNotEmpty) {
                                    showImageViewer(context, FileImage(File(path)));
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: AppColors.strokeStrong),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.45),
                                        blurRadius: 28,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: MealImage(
                                    path: path,
                                    bytes: bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: const Icon(Icons.close_rounded, color: AppColors.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
