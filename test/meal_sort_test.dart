import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';

void main() {
  List<Map<String, dynamic>> meals() => [
        {'id': 'a', 'loggedAt': 1000, 'name': 'Frühstück'},
        {'id': 'c', 'loggedAt': 3000, 'name': 'Abendessen'},
        {'id': 'b', 'loggedAt': 2000, 'name': 'Mittag'},
      ];

  test('oldest first keeps breakfast at the top', () {
    final list = meals();
    CalorieSummaryScreenModel.sortMealsChronologically(list);
    expect(list.map((m) => m['name']), ['Frühstück', 'Mittag', 'Abendessen']);
  });

  test('newest first puts the latest meal on top', () {
    final list = meals();
    CalorieSummaryScreenModel.sortMealsChronologically(list, newestFirst: true);
    expect(list.map((m) => m['name']), ['Abendessen', 'Mittag', 'Frühstück']);
  });

  test('display order remaps without mutating the source list', () {
    final list = meals();
    final newest = CalorieSummaryScreenModel.mealDisplayOrder(list, newestFirst: true);
    final oldest = CalorieSummaryScreenModel.mealDisplayOrder(list, newestFirst: false);

    expect(newest.map((i) => list[i]['name']), ['Abendessen', 'Mittag', 'Frühstück']);
    expect(oldest.map((i) => list[i]['name']), ['Frühstück', 'Mittag', 'Abendessen']);
    expect(list[0]['name'], 'Frühstück');
  });
}
