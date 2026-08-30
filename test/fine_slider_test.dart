import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/widgets/fine_slider.dart';

void main() {
  test('only a crawl fully zooms in', () {
    expect(FineSlider.zoomFromSpeed(0.02), 1);
    expect(FineSlider.zoomFromSpeed(0.03), 1);
    expect(FineSlider.zoomFromSpeed(0.08), lessThan(0.6));
  });

  test('a flick and normal drag stay zoomed out', () {
    expect(FineSlider.zoomFromSpeed(0.22), 0);
    expect(FineSlider.zoomFromSpeed(0.5), 0);
    expect(FineSlider.zoomFromSpeed(1.2), 0);
  });

  test('medium crawl sits between', () {
    final mid = FineSlider.zoomFromSpeed(0.10);
    expect(mid, greaterThan(0.15));
    expect(mid, lessThan(0.75));
  });
}
