import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';
import 'package:simple_calorie_tracker/widgets/app_dialog.dart';

ScrollPosition _dialogScroll(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(AppDialogCard),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
}

void main() {
  testWidgets('dialog stays put without keyboard and scrolls when it covers the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const AppDialogCard(
          icon: Icons.restaurant_rounded,
          title: 'Mahlzeit',
          child: SizedBox(height: 520, child: Text('Formular')),
        ),
      ),
    );

    expect(_dialogScroll(tester).maxScrollExtent, 0);

    tester.view.viewInsets = const FakeViewPadding(bottom: 380);
    await tester.pumpAndSettle();

    expect(_dialogScroll(tester).maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.descendant(
        of: find.byType(AppDialogCard),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();

    expect(_dialogScroll(tester).pixels, greaterThan(0));
  });
}
