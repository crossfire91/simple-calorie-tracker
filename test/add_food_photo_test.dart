import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_calorie_tracker/AddFoodAlertBody/AddFoodAlertBody.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';
import 'package:simple_calorie_tracker/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return LocaleScope(
    controller: LocaleController(AppLang.de),
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('photo is optional and does not start Gemini by itself', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AddFoodAlertBody(
          onAddFood: (_) async {},
        ),
      ),
    );

    expect(find.text('Foto dazu'), findsOneWidget);
    expect(find.text('Optional · bleibt im Tagebuch'), findsOneWidget);
    expect(find.text('Schätzen'), findsOneWidget);
    expect(find.text('Diesen Text nachschlagen'), findsNothing);
    expect(find.text('Eintragen'), findsOneWidget);

    await tester.tap(find.text('Schätzen'));
    await tester.pump();
    expect(find.text('Schreib was du isst, oder mach ein Foto.'), findsOneWidget);
  });
}
