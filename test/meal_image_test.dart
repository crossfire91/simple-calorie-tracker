import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/widgets/meal_image.dart';

void main() {
  test('decodeMealImageBytes reads sqlite blobs and base64', () {
    final raw = Uint8List.fromList([1, 2, 3, 4]);
    expect(decodeMealImageBytes(raw), raw);
    expect(decodeMealImageBytes({'imageBlob': raw}), raw);
    expect(decodeMealImageBytes({'imageBytes': raw}), raw);
    expect(decodeMealImageBytes(base64Encode(raw)), raw);
    expect(decodeMealImageBytes(null), isNull);
    expect(decodeMealImageBytes(Uint8List(0)), isNull);
  });
}
