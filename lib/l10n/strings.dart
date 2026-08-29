import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/goal/daily_target.dart';
import 'package:simple_calorie_tracker/goal/weight_journey.dart';
import 'package:simple_calorie_tracker/habit/rest_of_day.dart';
import 'package:simple_calorie_tracker/l10n/app_lang.dart';

class S {
  final AppLang lang;
  const S(this.lang);

  static S of(BuildContext context) {
    final scoped = LocaleScope.of(context).lang;
    if (scoped == AppLang.de) return const S(AppLang.de);
    final code = Localizations.maybeLocaleOf(context)?.languageCode;
    if (code == 'de') return const S(AppLang.de);
    return S(scoped);
  }

  bool get isDe => lang == AppLang.de;
  String _t(String en, String de) => isDe ? de : en;

  String get languageShort => isDe ? 'DE' : 'EN';
  String get languageOtherShort => isDe ? 'EN' : 'DE';

  String get goodMorning => _t('Good morning', 'Guten Morgen');
  String get goodAfternoon => _t('Good afternoon', 'Guten Tag');
  String get goodEvening => _t('Good evening', 'Guten Abend');

  String greeting(int hour) {
    if (hour < 12) return goodMorning;
    if (hour < 18) return goodAfternoon;
    return goodEvening;
  }

  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthsDe = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];
  static const _monthsShortEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsShortDe = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
  ];

  String prettyDate(DateTime date) {
    final months = isDe ? _monthsDe : _monthsEn;
    return isDe
        ? '${date.day}. ${months[date.month - 1]}'
        : '${months[date.month - 1]} ${date.day}';
  }

  String monthShort(int month) =>
      (isDe ? _monthsShortDe : _monthsShortEn)[month - 1];

  String get welcomeTitle => _t('Your daily calorie target', 'Dein Kalorienziel für heute');
  String get dailyTarget => _t('Daily target', 'Tagesziel');
  String get welcomeSubtitle => _t(
        'We calculate a healthy daily target from your goal — or you enter the number yourself.',
        'Wir berechnen aus deinem Ziel ein gesundes Tageslimit — oder du trägst die Zahl selbst ein.',
      );
  String get dailyTargetSubtitle => _t(
        'This is how many calories you have left each day. You can change it anytime.',
        'So viele Kalorien bleiben dir pro Tag. Du kannst das Ziel jederzeit ändern.',
      );

  String get logWeightTitle => _t('Log your weight', 'Gewicht eintragen');
  String get logWeightSubtitle => _t(
        'Your calorie target follows today’s weight.',
        'Das Kalorienziel richtet sich nach deinem heutigen Gewicht.',
      );
  String get photoEstimate => _t('Photo estimate', 'Foto-Schätzung');
  String get photoEstimateSubtitle => _t(
        'Gemini reads the plate. USDA and Open Food Facts first. Web search only if those miss.',
        'Gemini liest den Teller. Zuerst USDA und Open Food Facts. Websuche nur wenn beide fehlen.',
      );
  String get anotherServing => _t('Another serving', 'Noch eine Portion');
  String get logAMeal => _t('Log a meal', 'Mahlzeit eintragen');
  String get anotherServingSubtitle => _t('Same food. Just more of it.', 'Dasselbe Essen. Nur mehr davon.');
  String get logAMealSubtitle => _t(
        'Write what you are eating, or add a photo. Estimate only if you want.',
        'Schreib was du isst, oder mach ein Foto. Schätzen nur wenn du willst.',
      );
  String get removeMealTitle => _t('Remove this meal?', 'Diese Mahlzeit entfernen?');
  String get removeMealSubtitle => _t(
        'This meal will be deleted. Those calories are added back.',
        'Die Mahlzeit wird gelöscht. Die Kalorien werden wieder gutgeschrieben.',
      );
  String get remove => _t('Remove', 'Entfernen');
  String get todayMeals => _t("TODAY'S MEALS", 'HEUTIGE MAHLZEITEN');
  String get addFood => _t('Add food', 'Essen hinzufügen');
  String get kcalLeft => _t('KCAL LEFT', 'KCAL ÜBRIG');
  String get overBudget => _t('OVER BUDGET', 'ÜBER DEM ZIEL');
  String get nothingLogged => _t('Nothing logged yet', 'Noch nichts eingetragen');
  String get tapPlus => _t('Tap + to log your first meal.', 'Tippe auf +, um die erste Mahlzeit einzutragen.');
  String get noPhotos => _t('No photos yet', 'Noch keine Fotos');
  String get mealGallery => _t('Meal gallery', 'Foto-Galerie');
  String get onePhoto => _t('1 photo', '1 Foto');
  String photoOf(int index, int total) =>
      _t('${index + 1} of $total', '${index + 1} von $total');

  String get gotIt => _t('Got it', 'Verstanden');
  String get cancel => _t('Cancel', 'Abbrechen');

  String get calculate => _t('Calculate', 'Berechnen');
  String get enterNumber => _t('Enter number', 'Zahl eingeben');
  String get yourNumber => _t('Your number', 'Deine Zahl');
  String get yourNumberLabel => _t('YOUR NUMBER', 'DEINE ZAHL');
  String get aimingFor => _t('WHAT ARE WE AIMING FOR?', 'WOHIN SOLL ES GEHEN?');
  String get sexHeading => _t('SEX', 'GESCHLECHT');
  String get lose => _t('Lose', 'Abnehmen');
  String get loseHint => _t('Lose weight', 'Gewicht runter');
  String get keep => _t('Keep', 'Halten');
  String get keepHint => _t('Stay the same', 'Gewicht halten');
  String get gain => _t('Gain', 'Zunehmen');
  String get gainHint => _t('Gain weight', 'Gewicht rauf');
  String get woman => _t('Woman', 'Frau');
  String get man => _t('Man', 'Mann');
  String get skip => _t('Skip', 'Egal');
  String get age => _t('Age', 'Alter');
  String get years => _t('years', 'Jahre');
  String get height => _t('Height', 'Größe');
  String get weight => _t('Weight', 'Gewicht');
  String get aNormalWeek => _t('A normal week', 'Eine normale Woche');
  String get howQuickly => _t('How quickly', 'Wie schnell');
  String get howYouGrow => _t('How fast to gain', 'Wie schnell zunehmen');
  String get startTracking => _t('Start tracking', 'Loslegen');
  String get saveThisNumber => _t('Save this number', 'Diese Zahl speichern');
  String get estimateDisclaimer => _t(
        'An estimate for healthy adults. Mifflin–St Jeor · ACSM / Academy of Nutrition. Not medical advice.',
        'Eine Schätzung für gesunde Erwachsene. Mifflin–St Jeor · ACSM / Academy of Nutrition. Kein medizinischer Rat.',
      );
  String get kcalPerDay => _t('KCAL / DAY', 'KCAL / TAG');
  String get slideALittle => _t('Move the slider to set your number.', 'Zieh am Regler, um die Zahl festzulegen.');
  String get yourDayInOneNumber => _t('Your daily calorie target', 'Dein Kalorienziel für heute');
  String get holdThisBalance => _t('Maintain your weight', 'Gewicht halten');
  String weekKind(double kg, {required bool gain}) {
    final sign = gain ? '+' : '−';
    return _t(
      '$sign${kg.toStringAsFixed(2)} kg / week',
      '$sign${kg.toStringAsFixed(2)} kg / Woche',
    );
  }

  List<String> get activityLabels => isDe
      ? const ['Schreibtisch', 'Etwas Bewegung', 'Viel auf den Beinen', 'Ich trainiere', 'Sehr harte Wochen']
      : const ['Desk days', 'A little movement', 'On my feet', 'I train', 'Very hard weeks'];

  String paceName(double kg, bool loseGoal) {
    if (loseGoal) {
      if (kg <= 0.32) return _t('Gentle', 'Sanft');
      if (kg <= 0.58) return _t('Steady', 'Gleichmäßig');
      if (kg <= 0.82) return _t('Brisk', 'Zügig');
      return _t('Ambitious', 'Ambitioniert');
    }
    if (kg <= 0.18) return _t('Slow', 'Langsam');
    if (kg <= 0.28) return _t('Steady', 'Gleichmäßig');
    if (kg <= 0.42) return _t('Solid', 'Kräftig');
    return _t('Fast', 'Schnell');
  }

  String _kg(double v) {
    final text = v.toStringAsFixed(2);
    return isDe ? text.replaceAll('.', ',') : text;
  }

  String _onePercentWouldBe(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return '';
    return _t(
      ' (1% of ${_kg(weightKg)} kg = ${_kg(weightKg * 0.01)} kg)',
      ' (1 % von ${_kg(weightKg)} kg = ${_kg(weightKg * 0.01)} kg)',
    );
  }

  String targetNote(TargetNote kind, double kg, {double? weightKg}) {
    switch (kind) {
      case TargetNote.manualLow:
        return _t(
          'That’s below the Academy of Nutrition and Dietetics floor for self-guided diets (about 1200 kcal for women, 1500 for men).',
          'Das liegt unter der Untergrenze der Academy of Nutrition and Dietetics für Diäten ohne Aufsicht (etwa 1200 kcal für Frauen, 1500 für Männer).',
        );
      case TargetNote.maintain:
        return _t(
          'Maintenance = TDEE: Mifflin–St Jeor resting burn × ACSM / FAO activity factor.',
          'Halten = Tagesverbrauch (TDEE): Ruheumsatz nach Mifflin–St Jeor × Aktivitätsfaktor nach ACSM / FAO.',
        );
      case TargetNote.underweightBlocked:
        return _t(
          'BMI is under 18.5 (WHO underweight). A deficit is not calculated — only maintenance.',
          'Der BMI liegt unter 18,5 (WHO: Untergewicht). Ein Defizit wird nicht gerechnet — nur Halten.',
        );
      case TargetNote.loseCappedDeficit:
        return _t(
          'Here the 1% rule is not the limit${_onePercentWouldBe(weightKg)}. ACSM and the Academy of Nutrition cap an unsupervised deficit at about 25% of daily burn — for you that is ${_kg(kg)} kg/week. A larger cut burns muscle, not just fat.',
          'Hier greift nicht die 1-%-Regel${_onePercentWouldBe(weightKg)}. ACSM und die Academy of Nutrition begrenzen ein Defizit ohne Aufsicht auf etwa 25 % des Tagesverbrauchs — bei dir sind das ${_kg(kg)} kg/Woche. Ein größeres Defizit verbraucht oft Muskel, nicht nur Fett.',
        );
      case TargetNote.loseCappedFloor:
        return _t(
          'Not below resting burn (Mifflin–St Jeor) and not below the Academy of Nutrition floors (1200 / 1500 kcal). Below BMR the body uses muscle and metabolism slows — that is not faster fat loss.',
          'Nicht unter dem Ruheumsatz (Mifflin–St Jeor) und nicht unter den Untergrenzen der Academy of Nutrition (1200 / 1500 kcal). Unter dem BMR holt sich der Körper Muskeln, der Stoffwechsel wird langsamer — das ist kein schnelleres Abnehmen.',
        );
      case TargetNote.loseCappedPace:
        return _t(
          'Weekly loss is capped at 1% of your body weight${_onePercentWouldBe(weightKg)}. ACSM, the Academy of Nutrition and Harvard Health treat 0.5–1 kg/week as the usual band; 1% is the ceiling for everyone, and it is tighter than 1 kg when you weigh less than 100 kg. Faster loss is often muscle and water, not fat.',
          'Höchstens 1 % deines Körpergewichts pro Woche${_onePercentWouldBe(weightKg)}. ACSM, Academy of Nutrition und Harvard Health nennen 0,5–1 kg/Woche als üblichen Rahmen; 1 % gilt für alle als Deckel — und ist unter 100 kg strenger als 1 kg. Schnellerer Verlust ist oft Muskel und Wasser, nicht Fett.',
        );
      case TargetNote.loseOk:
        return _t(
          'About ${kg.toStringAsFixed(2)} kg / week. Calories: Mifflin–St Jeor × ACSM activity. Pace: ACSM / Academy of Nutrition (~0.5–1 kg/week).',
          'Etwa ${kg.toStringAsFixed(2)} kg / Woche. Kalorien: Mifflin–St Jeor × ACSM-Aktivität. Tempo: ACSM / Academy of Nutrition (etwa 0,5–1 kg/Woche).',
        );
      case TargetNote.gainCapped:
        return _t(
          'Surplus capped at 20% of TDEE and about 0.5% of body weight / week (ISSN lean-gain guidance), so more of the gain is muscle, not fat.',
          'Überschuss höchstens 20 % des Tagesverbrauchs und etwa 0,5 % des Körpergewichts / Woche (ISSN, langsamer Muskelaufbau) — damit das Plus eher Muskel bleibt, nicht Fett.',
        );
      case TargetNote.gainOk:
        return _t(
          'About +${kg.toStringAsFixed(2)} kg / week. Slow surplus after ISSN guidance for lean gain.',
          'Etwa +${kg.toStringAsFixed(2)} kg / Woche. Langsamer Überschuss nach ISSN für eher muskulösen Aufbau.',
        );
    }
  }

  String get geminiKey => _t('Gemini key', 'Gemini-Schlüssel');
  String get geminiKeyHint => _t('from aistudio.google.com', 'von aistudio.google.com');
  String get usdaKey => _t('USDA key', 'USDA-Schlüssel');
  String get usdaKeyHint => _t('optional · DEMO_KEY works', 'optional · DEMO_KEY reicht');
  String get keysHelp => _t(
        'Gemini names the food and grams. Calories come from USDA, then Open Food Facts. Google Search is the last fallback and stays marked unverified.',
        'Gemini nennt Essen und Gramm. Kalorien kommen von USDA, dann Open Food Facts. Google-Suche ist der letzte Fallback und bleibt als unsicher markiert.',
      );
  String get saveKeys => _t('Save keys', 'Schlüssel speichern');

  String get energy => _t('Energy', 'Energie');
  String get gramsHint => _t('g', 'g');
  String get kcalPer100g => _t('kcal / 100g', 'kcal / 100g');
  String get whatIsIt => _t('What are you eating?', 'Was isst du?');
  String get whatIsItHint => _t('pizza, salad, a doner', 'Pizza, Salat, ein Döner');
  String get estimateNeedsInput => _t(
        'Write what you are eating, or add a photo.',
        'Schreib was du isst, oder mach ein Foto.',
      );
  String get lookingUp => _t('Looking up…', 'Wird gesucht…');
  String get lookUpThisText => _t('Look up this text', 'Diesen Text nachschlagen');
  String get addAPhoto => _t('Add a photo', 'Foto dazu');
  String get photoStaysLocal => _t('Optional · stays in your log', 'Optional · bleibt im Tagebuch');
  String get estimatePlate => _t('Estimate', 'Schätzen');
  String get webUnverified => _t('Web · unverified', 'Web · unsicher');
  String get webFallbackNote => _t(
        'Web numbers are a last resort. Check them before you log.',
        'Web-Zahlen sind der letzte Ausweg. Prüfe sie vor dem Speichern.',
      );
  String get estimating => _t('Estimating', 'Schätzen');
  String get retake => _t('Retake', 'Neu');
  String get removePhoto => _t('Remove', 'Weg');
  String get gallery => _t('Gallery', 'Galerie');
  String get working => _t('Working…', 'Arbeitet…');
  String get reEstimate => _t('Re-estimate', 'Neu schätzen');
  String get addServing => _t('Add serving', 'Portion dazu');
  String get logMeal => _t('Log meal', 'Eintragen');
  String get readingPlate => _t('Reading the plate…', 'Der Teller wird gelesen…');
  String get lookingThatUp => _t('Looking that up…', 'Wird nachgeschlagen…');
  String get couldNotOpenPhoto => _t('Could not open that photo.', 'Das Foto ließ sich nicht öffnen.');
  String get nothingToLookUp => _t('Nothing to look up.', 'Nichts zum Nachschlagen.');
  String get weightAndEnergy => _t('Enter weight and calories first.', 'Trag zuerst Gewicht und Kalorien ein.');
  String get noMatchWriteSimpler => _t(
        'Write a simpler name, or type energy yourself.',
        'Schreib einen einfacheren Namen, oder tippe die Energie selbst.',
      );
  String editIfOff(int totalKcal) => _t(
        'Edit the fields if the portion looks off. $totalKcal kcal total.',
        'Passe die Felder an, wenn die Portion nicht stimmt. $totalKcal kcal insgesamt.',
      );
  String noMatchFor(String names) => _t(
        'No USDA / Open Food Facts match for $names. Weight is filled. Type energy, or try a simpler name.',
        'Kein Treffer in USDA / Open Food Facts für $names. Gewicht ist da. Energie tippen, oder einen einfacheren Namen.',
      );
  String noMatchEnergyOnly(String names) => _t(
        'No match for $names. Energy is only the matched items.',
        'Kein Treffer für $names. Die Energie gilt nur für die erkannten Teile.',
      );
  String gramsNoMatch(int grams) => _t('${grams}g · no match', '${grams}g · kein Treffer');

  String lookupError(String raw) {
    final text = raw.replaceFirst('Bad state: ', '');
    if (text.contains('Gemini API key') || text.contains('settings')) {
      return _t(
        'Add a Gemini API key in settings. Calories still come from USDA / Open Food Facts.',
        'Lege in den Einstellungen einen Gemini-Schlüssel an. Kalorien kommen weiter von USDA / Open Food Facts.',
      );
    }
    if (text.contains('Write what it actually is')) {
      return _t('Write what it actually is. Grams are optional.', 'Schreib, was es wirklich ist. Gramm sind optional.');
    }
    if (text.contains('No food was visible')) {
      return _t('No food was visible enough to estimate.', 'Es war nicht genug Essen zu sehen.');
    }
    if (text.contains('could not read the photo')) {
      return _t('Gemini could not read the photo.', 'Gemini konnte das Foto nicht lesen.');
    }
    if (text.contains('Could not parse that description')) {
      return _t('Could not parse that description.', 'Diese Beschreibung ließ sich nicht lesen.');
    }
    if (text.contains('could not read that description')) {
      return _t('Gemini could not read that description.', 'Gemini konnte die Beschreibung nicht lesen.');
    }
    if (text.contains('rejected the key')) {
      return _t('Gemini rejected the key or request.', 'Gemini hat den Schlüssel oder die Anfrage abgelehnt.');
    }
    return text;
  }

  String get yourJourney => _t('YOUR JOURNEY', 'DEIN VERLAUF');
  String get log => _t('Log', 'Log');
  String get start => _t('Start', 'Start');
  String get now => _t('Now', 'Jetzt');
  String get change => _t('Change', 'Änderung');
  String get logToBeginLine => _t('Log a weigh-in to begin the line.', 'Trag ein Gewicht ein, dann beginnt die Linie.');
  String sinceDate(DateTime date) =>
      _t('Since ${monthShort(date.month)} ${date.day}', 'Seit ${date.day}. ${monthShort(date.month)}');
  String get firstWeighInHint => _t(
        'Your first weigh-in becomes the start of the line.',
        'Dein erstes Gewicht wird der Anfang der Linie.',
      );
  String get lineStartsToday => _t('The line starts when you log today.', 'Die Linie beginnt, wenn du heute einträgst.');
  String get daysYouShowedUp => _t('DAYS YOU LOGGED', 'TAGE MIT EINTRAG');
  String get trackedDaysHint => _t(
        'Green: on target. Coral: over. Grey: nothing logged.',
        'Grün: im Ziel. Koralle: drüber. Grau: nichts eingetragen.',
      );
  String streakLabel(int days) {
    if (days <= 0) return _t('Start a streak', 'Streak starten');
    if (days == 1) return _t('1 day streak', '1 Tag am Stück');
    return _t('$days day streak', '$days Tage am Stück');
  }

  String get ringClosed => _t('Target reached', 'Ziel erreicht');
  String get youClosedIt => _t('You hit today’s target.', 'Du hast das Tagesziel erreicht.');
  String get vsYesterday => _t('vs yesterday', 'vs. gestern');
  String get yesterdayGhost => _t('YESTERDAY', 'GESTERN');

  String get yourMoves => _t('FAVORITES', 'FAVORITEN');
  String get tapToLog => _t('Tap once to log it.', 'Ein Tipp genügt zum Eintragen.');
  String get pinMeal => _t('Pin', 'Merken');
  String get pinned => _t('Pinned', 'Gemerkt');
  String get saveAsFavorite => _t('Save as a favorite', 'Als Favorit speichern');
  String get unnamedMeal => _t('Meal', 'Mahlzeit');
  String get removeFavorite => _t('Remove favorite?', 'Favorit entfernen?');
  String get removeFavoriteSubtitle => _t(
        'It leaves the row. Today’s log stays.',
        'Es verschwindet aus der Reihe. Der heutige Eintrag bleibt.',
      );

  String get restOfDay => _t('REST OF DAY', 'REST DES TAGES');
  String get coachMorning => _t('MORNING', 'MORGEN');
  String get coachEvening => _t('EVENING', 'ABEND');
  String get coachProtein => _t('PROTEIN', 'PROTEIN');
  String get coachAdd => _t('+ New', '+ Neu');
  String proteinStill(int grams) =>
      _t('$grams g protein still open', 'Noch $grams g Protein offen');
  String proteinOfTarget(int grams, int target) =>
      _t('$grams / $target g', '$grams / $target g');

  String coachEyebrow(CoachMood mood) {
    switch (mood) {
      case CoachMood.morningOpen:
        return coachMorning;
      case CoachMood.proteinPush:
        return coachProtein;
      case CoachMood.dinner:
      case CoachMood.latePlate:
        return coachEvening;
      case CoachMood.over:
      case CoachMood.closed:
      case CoachMood.lateSip:
      case CoachMood.nextPlate:
        return restOfDay;
    }
  }

  String coachLine(RestOfDayPlan plan) {
    final name = plan.primary?.label(isDe);
    switch (plan.mood) {
      case CoachMood.morningOpen:
        return _t(
          'The day is open. First plate whenever you want.',
          'Tag ist offen. Erstes Essen, wann du willst.',
        );
      case CoachMood.closed:
        return restClosed();
      case CoachMood.over:
        return restOver(plan.remaining);
      case CoachMood.lateSip:
        return restSip(plan.remaining);
      case CoachMood.proteinPush:
        if (name == null) {
          return _t(
            '${plan.remaining} kcal left and ${plan.proteinLeft} g protein. Something simple and high-protein.',
            'Noch ${plan.remaining} kcal und ${plan.proteinLeft} g Protein. Etwas Einfaches mit viel Protein.',
          );
        }
        return _t(
          '${plan.remaining} kcal left and ${plan.proteinLeft} g protein. $name covers that.',
          'Noch ${plan.remaining} kcal und ${plan.proteinLeft} g Protein. Das schafft $name.',
        );
      case CoachMood.dinner:
        if (name == null) return restSip(plan.remaining);
        return _t(
          '${plan.remaining} kcal left. That is dinner — $name.',
          'Noch ${plan.remaining} kcal. Das ist ein Abendessen — $name.',
        );
      case CoachMood.latePlate:
        if (name == null) return restSip(plan.remaining);
        return _t(
          '${plan.remaining} left this late. One plate, then done — $name.',
          'Noch ${plan.remaining} so spät. Eine Platte, dann Schluss — $name.',
        );
      case CoachMood.nextPlate:
        if (name == null) return restSip(plan.remaining);
        final second = plan.suggestions.length > 1 ? plan.suggestions[1].label(isDe) : null;
        if (second == null) {
          return _t(
            '${plan.remaining} kcal left. Next up, that fits $name.',
            'Noch ${plan.remaining} kcal. Als Nächstes reicht das für $name.',
          );
        }
        return _t(
          '${plan.remaining} kcal left. Next up, $name or $second.',
          'Noch ${plan.remaining} kcal. Als Nächstes $name oder $second.',
        );
    }
  }

  String restClosed() => _t(
        'Target reached. Water, a walk — done.',
        'Ziel erreicht. Wasser, ein Spaziergang — fertig.',
      );
  String restOver(int extra) => _t(
        '$extra kcal over. Tomorrow is a new day.',
        '$extra kcal drüber. Morgen ist ein neuer Tag.',
      );
  String restSip(int left) => _t(
        '$left kcal left. Tea is enough.',
        'Noch $left kcal. Ein Tee reicht.',
      );
  String restFits(int left, String a, String? b) {
    if (b == null || b.isEmpty) {
      return _t(
        '$left kcal left. That fits $a.',
        'Noch $left kcal. Das reicht für $a.',
      );
    }
    return _t(
      '$left kcal left. That fits $a or $b.',
      'Noch $left kcal. Das reicht für $a oder $b.',
    );
  }

  String get microGoals => _t('TODAY’S SMALL GOALS', 'KLEINE ZIELE HEUTE');
  String get microGoalsThatDay => _t("THAT DAY'S SMALL GOALS", 'KLEINE ZIELE DES TAGES');
  String ringsClosed(int n) => n == 1
      ? _t('1 ring closed', '1 Ring zu')
      : _t('$n rings closed', '$n Ringe zu');
  String get breakfastGoal => _t('Breakfast', 'Frühstück');
  String get proteinGoal => _t('Protein', 'Protein');
  String get noLateGoal => _t('No late snack', 'Kein später Snack');
  String proteinGoalLine(int grams, int target) =>
      _t('$grams / $target g', '$grams / $target g');

  String get weekOnYourPlate => _t('THIS WEEK ON YOUR PLATE', 'DIESE WOCHE AUF DEM TELLER');
  String get swipeTheWeek => _t('Swipe through the week', 'Woche durchblättern');

  String get snapAPlate => _t('Take a photo', 'Foto machen');
  String logThisPlate(int kcal) => _t('Log this plate · $kcal kcal', 'Teller eintragen · $kcal kcal');
  String get lookingAtThePlate => _t(
        'The photo stays in your log. Estimate only if you want.',
        'Das Foto bleibt im Tagebuch. Schätzen nur wenn du willst.',
      );

  String trendLabel(GoalType goal, double plannedKgPerWeek) {
    if (plannedKgPerWeek < 0.05) return _t('Holding', 'Halten');
    switch (goal) {
      case GoalType.lose:
        return _t('Losing', 'Abnehmen');
      case GoalType.gain:
        return _t('Gaining', 'Zunehmen');
      case GoalType.maintain:
        return _t('Holding', 'Halten');
    }
  }

  String weekLine(GoalType goal, double plannedKgPerWeek) {
    if (plannedKgPerWeek < 0.05) return _t('Keeping this weight', 'Dieses Gewicht halten');
    final sign = goal == GoalType.gain ? '+' : '−';
    return _t(
      '$sign${plannedKgPerWeek.toStringAsFixed(2)} kg / week',
      '$sign${plannedKgPerWeek.toStringAsFixed(2)} kg / Woche',
    );
  }

  String atKgKcal(double kg, int kcal) =>
      _t('At ${kg.toStringAsFixed(1)} kg  ·  $kcal kcal', 'Bei ${kg.toStringAsFixed(1)} kg  ·  $kcal kcal');

  String paceHint(PaceHint hint) {
    switch (hint) {
      case PaceHint.holdSteady:
        return _t('Your weight is stable.', 'Dein Gewicht ist stabil.');
      case PaceHint.holdUp:
        return _t('A bit above the start. The goal is to maintain.', 'Etwas über dem Startgewicht. Das Ziel ist Halten.');
      case PaceHint.holdDown:
        return _t('A bit below the start. The goal is to maintain.', 'Etwas unter dem Startgewicht. Das Ziel ist Halten.');
      case PaceHint.onPace:
        return _t('You are on track.', 'Du liegst im Plan.');
      case PaceHint.ahead:
        return _t('A bit ahead of the plan.', 'Etwas vor dem Plan.');
      case PaceHint.behind:
        return _t('A bit behind the plan.', 'Etwas hinter dem Plan.');
    }
  }

  String onDate(DateTime date) =>
      _t('On ${date.day}.${date.month}.${date.year}', 'Am ${date.day}.${date.month}.${date.year}');
  String get orTypeIt => _t('Or type it', 'Oder tippen');
  String get saveWeighIn => _t('Save this weigh-in', 'Diesen Eintrag speichern');

  String get gentleHelpers => _t('SMALL TIPS', 'KLEINE TIPPS');
  String get gentleHelpersSubtitle => _t(
        'Simple products and habits that make eating less easier. No miracles.',
        'Einfache Produkte und Gewohnheiten, die das Abnehmen erleichtern. Keine Wunder.',
      );

  String lossTitle(LossHelper id) {
    switch (id) {
      case LossHelper.scale:
        return _t('Kitchen scale', 'Küchenwaage');
      case LossHelper.protein:
        return _t('Protein first', 'Erst Protein');
      case LossHelper.water:
        return _t('Sparkling water', 'Sprudelwasser');
      case LossHelper.volume:
        return _t('Filling plates', 'Sättigende Teller');
      case LossHelper.walk:
        return _t('Evening walk', 'Abendspaziergang');
    }
  }

  String lossTag(LossHelper id) {
    switch (id) {
      case LossHelper.scale:
        return _t('Honest portions', 'Ehrliche Portionen');
      case LossHelper.protein:
        return _t('Stay full', 'Länger satt');
      case LossHelper.water:
        return _t('Easy swap', 'Leichter Tausch');
      case LossHelper.volume:
        return _t('Big, light food', 'Groß, leicht');
      case LossHelper.walk:
        return _t('No gym needed', 'Ohne Sportstudio');
    }
  }

  String lossWhy(LossHelper id) {
    switch (id) {
      case LossHelper.scale:
        return _t(
          'A cheap kitchen scale keeps portions honest. You stop guessing what “a handful” weighs.',
          'Eine günstige Küchenwaage macht Portionen ehrlich. Du musst nicht mehr schätzen, was „eine Handvoll“ wiegt.',
        );
      case LossHelper.protein:
        return _t(
          'Eggs, Greek yogurt, cottage cheese, tofu, fish. Protein keeps you full so a calorie deficit is easier.',
          'Eier, griechischer Joghurt, Hüttenkäse, Tofu, Fisch. Protein sättigt länger, darum fällt das Defizit leichter.',
        );
      case LossHelper.water:
        return _t(
          'A large glass before a meal, or instead of a sweet drink, often saves a few hundred kcal.',
          'Ein großes Glas vor dem Essen — oder statt eines süßen Getränks — spart oft ein paar hundert kcal.',
        );
      case LossHelper.volume:
        return _t(
          'Broth, berries, cucumbers, big salads. The plate stays full, the calories stay lower.',
          'Brühe, Beeren, Gurken, große Salate. Der Teller bleibt voll, die Kalorien bleiben niedriger.',
        );
      case LossHelper.walk:
        return _t(
          'Twenty quiet minutes. Extra movement without a gym.',
          'Zwanzig ruhige Minuten. Extra Bewegung, ohne Fitnessstudio.',
        );
    }
  }

  String get calendarLocale => isDe ? 'de' : 'en_ISO';

  List<String> get weekdaysShort => isDe
      ? const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String monthYear(DateTime date) {
    final months = isDe ? _monthsDe : _monthsEn;
    return '${months[date.month - 1]} ${date.year}';
  }

  String get today => _t('Today', 'Heute');
  String weekLabel(int week) => _t('Week $week', 'Woche $week');
  String daysOfSeven(int n) => _t('$n / 7 days', '$n / 7 Tage');
  String avgKcal(int kcal) => _t('Ø $kcal kcal', 'Ø $kcal kcal');
  String get thisWeek => _t('This week', 'Diese Woche');
  String get emptyWeek => _t('Nothing logged', 'Noch leer');
  String get showMonth => _t('Show month', 'Monat zeigen');
  String get hideMonth => _t('Hide month', 'Monat schließen');
  String get previousWeek => _t('Previous week', 'Vorherige Woche');
  String get nextWeek => _t('Next week', 'Nächste Woche');
  String get previousMonth => _t('Previous month', 'Vorheriger Monat');
  String get nextMonth => _t('Next month', 'Nächster Monat');

  String mealsHeading(DateTime date) {
    final todayDate = DateTime.now();
    if (date.year == todayDate.year &&
        date.month == todayDate.month &&
        date.day == todayDate.day) {
      return todayMeals;
    }
    return _t('MEALS THIS DAY', 'MAHLZEITEN DES TAGES');
  }

  String dayDigestLine({
    required int kcal,
    required int budget,
    required int meals,
    required bool weighed,
  }) {
    final mealBit = meals == 1
        ? _t('1 meal', '1 Mahlzeit')
        : _t('$meals meals', '$meals Mahlzeiten');
    final weightBit = weighed ? _t(' · weighed', ' · gewogen') : '';
    return '$kcal / $budget kcal · $mealBit$weightBit';
  }

  String get dayEmpty => _t('Nothing logged this day.', 'An diesem Tag noch nichts.');

  String calendarDayLabel(DateTime date, {int? kcal, int meals = 0}) {
    final base = prettyDate(date);
    if (meals <= 0 && kcal == null) return base;
    if (kcal == null) return base;
    return _t('$base, $kcal kcal', '$base, $kcal kcal');
  }

  String get updateAvailable => _t('Update ready', 'Update bereit');
  String updateAvailableSubtitle(String version) =>
      _t('Version $version is ready to install.', 'Version $version ist bereit.');
  String get updateNow => _t('Update', 'Aktualisieren');
  String get updateLater => _t('Later', 'Später');
  String get updateDownloading => _t('Downloading update…', 'Update wird geladen…');
  String get updateFailed => _t('Update could not start.', 'Update ließ sich nicht starten.');
  String get updateChecking => _t('Checking…', 'Prüft…');
  String get updateUpToDate => _t('You are on the latest version.', 'Du bist auf dem neuesten Stand.');
  String get updateAllowInstall => _t(
        'Allow this app to install updates, then tap Update again.',
        'Erlaube dieser App, Updates zu installieren, und tippe dann nochmal auf Aktualisieren.',
      );
  String get checkForUpdate => _t('Check for update', 'Nach Update suchen');
  String currentVersion(String version) =>
      _t('Installed version $version', 'Installierte Version $version');
}

enum LossHelper { scale, protein, water, volume, walk }
