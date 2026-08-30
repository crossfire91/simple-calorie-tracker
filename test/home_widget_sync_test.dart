import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/platform/home_widget_sync.dart';

void main() {
  test('home widget sync stays silent off Android', () async {
    await HomeWidgetSync.publish(
      consumedKcal: 420,
      budgetKcal: 2100,
      dateKey: '29.8.2026',
      lang: 'de',
      mealCount: 2,
      streak: 4,
      favorites: const [
        {'id': 'a', 'name': 'Hähnchen', 'kcal': 350},
      ],
    );
    await HomeWidgetSync.publishLanguage('en');
  });

  test('parses add and favorite widget actions', () {
    final add = HomeWidgetSync.parseAction({'action': 'add', 'favoriteId': ''});
    expect(add?.isAdd, isTrue);
    expect(add?.isFavorite, isFalse);

    final favorite = HomeWidgetSync.parseAction({
      'action': 'favorite',
      'favoriteId': 'meal-1',
    });
    expect(favorite?.isFavorite, isTrue);
    expect(favorite?.favoriteId, 'meal-1');

    expect(HomeWidgetSync.parseAction({'action': ''}), isNull);
    expect(HomeWidgetSync.parseAction(null), isNull);
  });

  test('builds chronological plate lines for the journal widget', () {
    final eightFourteen = DateTime(2026, 8, 30, 8, 14).millisecondsSinceEpoch;
    final lines = HomeWidgetSync.mealLines([
      {
        'name': '  Hafer  ',
        'kcalPer100g': 350,
        'weightInGrams': 100,
        'loggedAt': eightFourteen,
      },
      {
        'name': '',
        'kcalPer100g': 200,
        'weightInGrams': 50,
        'loggedAt': 0,
      },
      {
        'name': 'Joghurt',
        'kcalPer100g': 80,
        'weightInGrams': 150,
        'loggedAt': DateTime(2026, 8, 30, 15, 2).millisecondsSinceEpoch,
      },
    ], limit: 2);

    expect(lines, [
      {'name': 'Hafer', 'kcal': 350, 'time': '08:14'},
      {'name': '', 'kcal': 100, 'time': ''},
    ]);
  });
}
