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
}
