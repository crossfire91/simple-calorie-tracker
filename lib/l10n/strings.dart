import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/backup/backup_payload.dart';
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
  String get settings => _t('Settings', 'Einstellungen');
  String get language => _t('Language', 'Sprache');
  String get apiKeys => _t('API keys', 'API-Schlüssel');

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

  String get welcomeTitle => _t('Daily calorie target', 'Kalorienziel');
  String get dailyTarget => _t('Daily target', 'Tagesziel');
  String get welcomeSubtitle => _t(
        'Calculated from your goal, or entered manually.',
        'Berechnet aus deinem Ziel — oder manuell gesetzt.',
      );
  String get dailyTargetSubtitle => _t(
        'Daily calorie budget. Editable at any time.',
        'Tägliches Kalorienbudget. Jederzeit änderbar.',
      );

  String get logWeightTitle => _t('Log weight', 'Gewicht eintragen');
  String get logWeightSubtitle => _t(
        'The calorie target updates from today’s weight.',
        'Das Kalorienziel folgt dem heutigen Gewicht.',
      );
  String get logWeightSubtitleManual => _t(
        'Weigh-in only. The calorie target stays unchanged.',
        'Nur der Wiegeeintrag. Das Kalorienziel bleibt unverändert.',
      );
  String get startingWeight => _t('Starting weight', 'Startgewicht');
  String get addStartingWeight =>
      _t('Add starting weight (optional)', 'Startgewicht angeben (optional)');
  String get skipStartingWeight => _t('Skip weight', 'Ohne Gewicht');
  String get photoEstimate => _t('Unlock estimate', 'Schätzen freischalten');
  String get photoEstimateSubtitle => _t(
        'A Gemini key enables estimates. Calories still come from USDA and Open Food Facts.',
        'Ein Gemini-Schlüssel aktiviert die Schätzung. Die kcal kommen weiter aus USDA und Open Food Facts.',
      );
  String get anotherServing => _t('Another serving', 'Weitere Portion');
  String get logAMeal => _t('Log a meal', 'Mahlzeit eintragen');
  String get editMeal => _t('Edit meal', 'Mahlzeit bearbeiten');
  String get editMealSubtitle => _t(
        'Adjust grams or kcal if the values are off.',
        'Gramm oder kcal anpassen, falls die Werte nicht stimmen.',
      );
  String get saveChanges => _t('Save changes', 'Speichern');
  String saveThisPlate(int kcal) =>
      _t('Save changes · $kcal kcal', 'Änderungen speichern · $kcal kcal');
  String get anotherServingSubtitle => _t(
        'Same item, additional serving.',
        'Dieselbe Mahlzeit, zusätzliche Portion.',
      );
  String get logAMealSubtitle => _t(
        'Describe the meal or add a photo. Estimate is optional.',
        'Mahlzeit beschreiben oder ein Foto hinzufügen. Die Schätzung ist optional.',
      );
  String get logFavoriteSubtitle => _t(
        'Confirm the values, then log.',
        'Werte prüfen, dann eintragen.',
      );
  String get removeMealTitle => _t('Remove this meal?', 'Mahlzeit entfernen?');
  String get removeMealSubtitle => _t(
        'The entry is deleted and the calories return to the daily budget.',
        'Der Eintrag wird gelöscht, die Kalorien gehen zurück ins Tagesbudget.',
      );
  String get remove => _t('Remove', 'Entfernen');
  String get todayMeals => _t("TODAY'S MEALS", 'HEUTIGE MAHLZEITEN');
  String get newestFirst => _t('Newest', 'Neueste');
  String get oldestFirst => _t('Oldest', 'Älteste');
  String get newestMealsFirst => _t('Newest meals first', 'Neueste Mahlzeiten zuerst');
  String get oldestMealsFirst => _t('Oldest meals first', 'Älteste Mahlzeiten zuerst');
  String mealGoalShare(int percent) =>
      _t('$percent% of the daily target', '$percent% vom Tagesziel');
  String clock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  String get addFood => _t('Add food', 'Essen hinzufügen');
  String get kcalLeft => _t('KCAL LEFT', 'KCAL ÜBRIG');
  String get stillOpen => _t('STILL OPEN', 'NOCH OFFEN');
  String get overBudget => _t('OVER BUDGET', 'ÜBER DEM ZIEL');
  String get nothingLogged => _t('Nothing logged', 'Keine Einträge');
  String get tapPlus => _t('Use + to add a meal.', 'Mit + eine Mahlzeit hinzufügen.');
  String get noPhotos => _t('No photos', 'Keine Fotos');
  String get mealGallery => _t('Meal gallery', 'Foto-Galerie');
  String get onePhoto => _t('1 photo', '1 Foto');
  String photoOf(int index, int total) =>
      _t('${index + 1} of $total', '${index + 1} von $total');

  String get gotIt => _t('Got it', 'Verstanden');
  String get cancel => _t('Cancel', 'Abbrechen');

  String get calculate => _t('Calculate', 'Berechnen');
  String get enterNumber => _t('Enter number', 'Zahl eingeben');
  String get yourNumber => _t('Custom target', 'Eigener Wert');
  String get yourNumberLabel => _t('CUSTOM TARGET', 'EIGENER WERT');
  String get aimingFor => _t('GOAL', 'ZIEL');
  String get sexHeading => _t('SEX', 'GESCHLECHT');
  String get lose => _t('Lose', 'Abnehmen');
  String get loseHint => _t('Lose weight', 'Gewicht reduzieren');
  String get keep => _t('Keep', 'Halten');
  String get keepHint => _t('Maintain weight', 'Gewicht halten');
  String get gain => _t('Gain', 'Zunehmen');
  String get gainHint => _t('Gain weight', 'Gewicht aufbauen');
  String get woman => _t('Woman', 'Frau');
  String get man => _t('Man', 'Mann');
  String get skip => _t('Unspecified', 'Keine Angabe');
  String get age => _t('Age', 'Alter');
  String get years => _t('years', 'Jahre');
  String get height => _t('Height', 'Größe');
  String get weight => _t('Weight', 'Gewicht');
  String get aNormalWeek => _t('Typical week', 'Typische Woche');
  String get howQuickly => _t('Pace', 'Tempo');
  String get howYouGrow => _t('Gain pace', 'Aufbautempo');
  String get startTracking => _t('Start tracking', 'Tracking starten');
  String get saveThisNumber => _t('Save this target', 'Ziel speichern');
  String get estimateDisclaimer => _t(
        'An estimate for healthy adults. Mifflin–St Jeor · ACSM / Academy of Nutrition. Not medical advice.',
        'Eine Schätzung für gesunde Erwachsene. Mifflin–St Jeor · ACSM / Academy of Nutrition. Kein medizinischer Rat.',
      );
  String get kcalPerDay => _t('KCAL / DAY', 'KCAL / TAG');
  String get slideALittle => _t('Set the target with the slider.', 'Ziel mit dem Regler festlegen.');
  String get yourDayInOneNumber => _t('Daily calorie target', 'Kalorienziel');
  String get holdThisBalance => _t('Maintain weight', 'Gewicht halten');
  String weekKind(double kg, {required bool gain}) {
    final sign = gain ? '+' : '−';
    return _t(
      '$sign${kg.toStringAsFixed(2)} kg / week',
      '$sign${kg.toStringAsFixed(2)} kg / Woche',
    );
  }

  List<String> get activityLabels => isDe
      ? const ['Sitzend', 'Leichte Aktivität', 'Überwiegend stehend', 'Regelmäßiges Training', 'Sehr hohe Belastung']
      : const ['Sedentary', 'Light activity', 'Mostly standing', 'Regular training', 'Very high load'];

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

  int? _kcal(double? v) => v != null && v > 0 ? v.round() : null;

  String targetNote(
    TargetNote kind,
    double kg, {
    double? weightKg,
    double? tdee,
    double? bmr,
    int? targetKcal,
  }) {
    final burn = _kcal(tdee);
    final eat = targetKcal != null && targetKcal > 0 ? targetKcal : null;

    switch (kind) {
      case TargetNote.manualLow:
        return _t(
          'Below 1200 kcal (women) or 1500 kcal (men), most people lose muscle and energy, not just fat. You can still use your number — just know what it costs.',
          'Unter 1200 kcal (Frauen) oder 1500 kcal (Männer) verliert man oft Muskel und Energie, nicht nur Fett. Du kannst den Wert trotzdem nehmen — dann weißt du, was er kostet.',
        );
      case TargetNote.maintain:
        if (eat != null) {
          return _t(
            'Your body uses about $eat kcal a day. Eat around that and the weight stays where it is.',
            'Dein Körper verbraucht am Tag etwa $eat kcal. Ungefähr so viel essen heißt: das Gewicht bleibt.',
          );
        }
        return _t(
          'This is about what your body uses in a day. Eat around that and the weight stays where it is.',
          'So viel verbraucht dein Körper am Tag. Ungefähr so viel essen heißt: das Gewicht bleibt.',
        );
      case TargetNote.underweightBlocked:
        return _t(
          'For this height the weight is already low. Cutting further would mostly take muscle and reserves you need. So the target is set to hold, not to lose.',
          'Für diese Größe ist das Gewicht bereits niedrig. Weiter runter würde vor allem Muskel und Reserven kosten, die du brauchst. Deshalb das Ziel zum Halten — nicht zum Abnehmen.',
        );
      case TargetNote.loseNoRoom:
        if (burn != null) {
          return _t(
            'You only burn about $burn kcal a day. Eating less would drop below what the body needs to function — that is shortage, not progress. So the target holds weight. Move more (walks, standing, training) and you burn more; then there is room to lose again.',
            'Du verbrauchst nur etwa $burn kcal am Tag. Weniger essen läge unter dem, was der Körper zum Funktionieren braucht — das wäre Mangel, kein Fortschritt. Deshalb bleibt das Ziel beim Halten. Wenn du dich mehr bewegst (gehen, stehen, trainieren), steigt der Verbrauch — dann ist wieder Platz zum Abnehmen.',
          );
        }
        return _t(
          'You already burn so little that eating less would be shortage, not progress. So the target holds weight. Move more and you burn more — then there is room to lose again.',
          'Du verbrauchst schon so wenig, dass weniger essen Mangel wäre, kein Fortschritt. Deshalb bleibt das Ziel beim Halten. Wenn du dich mehr bewegst, steigt der Verbrauch — dann ist wieder Platz zum Abnehmen.',
        );
      case TargetNote.loseCappedDeficit:
        if (burn != null && eat != null) {
          return _t(
            'You burn about $burn kcal a day — that is not what you should eat. To lose, you eat $eat kcal, about ${_kg(kg)} kg per week. A full kilo would mean cutting even harder. That often costs muscle and leaves you too empty to move. So we stay at $eat. Want it faster? Walk more, stand more, train — you burn more and lose quicker on the same food.',
            'Du verbrauchst etwa $burn kcal am Tag — das ist nicht das Essensziel. Zum Abnehmen isst du $eat kcal, etwa ${_kg(kg)} kg pro Woche. Ein ganzes Kilo ginge nur mit noch weniger Essen. Dann fehlt oft die Kraft, und der Verlust kommt als Muskel statt als Fett. Deshalb $eat kcal. Wer schneller abnehmen will: mehr gehen, stehen, trainieren — dann verbrennst du mehr und nimmst bei demselben Essen schneller ab.',
          );
        }
        return _t(
          'About ${_kg(kg)} kg per week. A full kilo would mean eating even less — that often costs muscle, not just fat. Want it faster? Move more and you burn more on the same food.',
          'Etwa ${_kg(kg)} kg pro Woche. Ein ganzes Kilo ginge nur mit noch weniger Essen — oft auf Kosten von Muskel, nicht nur Fett. Wer schneller will: mehr Bewegung, dann verbrennst du mehr bei demselben Essen.',
        );
      case TargetNote.loseCappedFloor:
        final andFloor = eat != null &&
            bmr != null &&
            bmr > 0 &&
            eat > bmr + 40;
        if (burn != null && eat != null && andFloor) {
          return _t(
            'Below $eat kcal a day, without a doctor, the body often breaks down muscle and runs on empty — the scale may drop, but you get weaker, not leaner. So $eat is the floor. You burn about $burn kcal, so the week is only ${_kg(kg)} kg. Want it faster? Move more. Then you burn more and lose quicker without eating even less.',
            'Unter $eat kcal am Tag, ohne ärztliche Begleitung, baut der Körper oft Muskel ab und läuft leer — die Waage kann fallen, du wirst aber schwächer, nicht definierter. Deshalb $eat kcal. Du verbrauchst etwa $burn kcal, darum nur ${_kg(kg)} kg pro Woche. Wer schneller abnehmen will: mehr Bewegung. Dann verbrennst du mehr und kommst voran, ohne noch weniger zu essen.',
          );
        }
        if (burn != null && eat != null) {
          return _t(
            'You burn about $burn kcal a day. Even at rest the body already needs $eat kcal — organs, muscle, the basics. Going lower does not make fat loss faster; it makes you hungrier and more likely to lose muscle. So $eat kcal, about ${_kg(kg)} kg per week. Weighing more does not speed that weekly loss by itself. Want it faster? Walk more in daily life. Then you burn more and lose quicker on the same food.',
            'Du verbrauchst am Tag etwa $burn kcal. Schon in Ruhe braucht der Körper $eat kcal — Organe, Muskel, der Grundbetrieb. Noch weniger zu essen macht das Abnehmen nicht schneller, sondern hungriger, und oft geht Muskel statt Fett. Deshalb $eat kcal und etwa ${_kg(kg)} kg pro Woche. Wer mehr wiegt, nimmt dadurch nicht automatisch schneller ab. Wer schneller will: mehr gehen im Alltag. Dann verbrennst du mehr und nimmst bei demselben Essen schneller ab.',
          );
        }
        return _t(
          'With little movement you barely burn more than the body needs at rest, so the week stays slow. Walk more and you burn more — then the same food loses faster.',
          'Bei wenig Bewegung verbrauchst du kaum mehr, als der Körper in Ruhe braucht — deshalb bleibt die Woche langsam. Mehr gehen, dann verbrennst du mehr und nimmst bei demselben Essen schneller ab.',
        );
      case TargetNote.loseCappedPace:
        if (weightKg != null && weightKg > 0) {
          return _t(
            'At ${_kg(weightKg)} kg, ${_kg(kg)} kg per week is 1% of your weight — faster than that and you often lose muscle, not just fat. 1 kg a week is meant for someone around 100 kg. Want it faster? Move more in daily life so you burn more. Eating even less is the worse lever.',
            'Bei ${_kg(weightKg)} kg sind ${_kg(kg)} kg pro Woche 1 % des Körpergewichts — schneller als das kostet oft Muskel, nicht nur Fett. 1 kg pro Woche ist für jemanden um die 100 kg gedacht. Wer schneller abnehmen will: mehr Bewegung im Alltag, dann verbrennst du mehr. Noch weniger essen ist der schlechtere Hebel.',
          );
        }
        return _t(
          '${_kg(kg)} kg per week is 1% of your weight — faster than that and you often lose muscle, not just fat. 1 kg a week is meant for someone around 100 kg. Want it faster? Move more so you burn more.',
          '${_kg(kg)} kg pro Woche sind 1 % des Körpergewichts — schneller als das kostet oft Muskel, nicht nur Fett. 1 kg pro Woche ist für jemanden um die 100 kg gedacht. Wer schneller will: mehr Bewegung, dann verbrennst du mehr.',
        );
      case TargetNote.loseOk:
        if (eat != null) {
          return _t(
            'At about $eat kcal a day you lose about ${_kg(kg)} kg per week — the pace you picked.',
            'Bei etwa $eat kcal am Tag nimmst du etwa ${_kg(kg)} kg pro Woche ab — das Tempo, das du gewählt hast.',
          );
        }
        return _t(
          'About ${_kg(kg)} kg per week — the pace you picked.',
          'Etwa ${_kg(kg)} kg pro Woche — das Tempo, das du gewählt hast.',
        );
      case TargetNote.gainCapped:
        return _t(
          'About +${_kg(kg)} kg per week. Faster than that and most of the extra is fat. Slower leaves more of it as muscle.',
          'Etwa +${_kg(kg)} kg pro Woche. Schneller, und das Extra wird vor allem Fett. Langsamer bleibt mehr davon Muskel.',
        );
      case TargetNote.gainOk:
        return _t(
          'A bit more than you burn: about +${_kg(kg)} kg per week, paced so more of it can be muscle.',
          'Etwas mehr, als du verbrauchst: etwa +${_kg(kg)} kg pro Woche, damit mehr davon Muskel werden kann.',
        );
    }
  }

  String get geminiKey => _t('Gemini key', 'Gemini-Schlüssel');
  String get geminiKeyHint => _t('from aistudio.google.com', 'von aistudio.google.com');
  String get usdaKey => _t('USDA key', 'USDA-Schlüssel');
  String get usdaKeyHint => _t('optional · DEMO_KEY works', 'optional · DEMO_KEY reicht');
  String get keysHelp => _t(
        'Gemini identifies the food and grams. Calories come from USDA, then Open Food Facts. Web search is the last fallback and stays marked unverified.',
        'Gemini erkennt Lebensmittel und Gramm. Kalorien kommen von USDA, dann Open Food Facts. Die Websuche ist der letzte Fallback und bleibt als unsicher markiert.',
      );
  String get saveKeys => _t('Save keys', 'Schlüssel speichern');

  String get energy => _t('Energy', 'Energie');
  String get gramsHint => _t('g', 'g');
  String get kcalPer100g => _t('kcal / 100g', 'kcal / 100g');
  String get orTotalKcal => _t('or total kcal', 'oder Gesamt-kcal');
  String get orKcalPer100g => _t('or kcal / 100g', 'oder kcal / 100g');
  String get totalEnergy => _t('Total', 'Gesamt');
  String get kcalHint => _t('kcal', 'kcal');
  String get enterCaloriesFirst => _t('Enter calories first.', 'Zuerst die Kalorien eintragen.');
  String get whatIsIt => _t('What are you eating?', 'Was isst du?');
  String get whatIsItHint => _t('pizza, salad, döner', 'Pizza, Salat, Döner');
  String get mealTitle => _t('Title', 'Titel');
  String get mealTitleHint => _t('short name', 'Kurzname');
  String get originalNote => _t('Original note', 'Originalbeschreibung');
  String get buildMenu => _t('Build a menu', 'Menü anlegen');
  String get addIngredient => _t('Add item', 'Zutat hinzufügen');
  String get lookUpMenu => _t('Look up items', 'Zutaten nachschlagen');
  String get menuHint => _t(
        'Same list the estimate uses. Adjust a name, then look up or enter kcal.',
        'Dieselbe Liste wie bei der Schätzung. Namen anpassen, dann nachschlagen oder kcal eingeben.',
      );
  String get itemName => _t('Name', 'Name');
  String get estimateNeedsInput => _t(
        'Describe the meal, dictate it, or add a photo.',
        'Mahlzeit beschreiben, diktieren oder ein Foto hinzufügen.',
      );
  String get lookingUp => _t('Looking up…', 'Wird gesucht…');
  String get lookUpThisText => _t('Look up this text', 'Diesen Text nachschlagen');
  String get addAPhoto => _t('Add a photo', 'Foto hinzufügen');
  String get photoStaysLocal => _t('Optional · stored in the log', 'Optional · bleibt im Tagebuch');
  String get estimatePlate => _t('Estimate', 'Schätzen');
  String get unlockEstimate => _t('Unlock estimate', 'Schätzen freischalten');
  String get webUnverified => _t('Web · unverified', 'Web · unsicher');
  String get webFallbackNote => _t(
        'Web numbers are a last resort. Check them before you log.',
        'Web-Zahlen sind der letzte Ausweg. Prüfe sie vor dem Speichern.',
      );
  String get estimating => _t('Estimating', 'Schätzen');
  String get retake => _t('Retake', 'Neu aufnehmen');
  String get removePhoto => _t('Remove', 'Entfernen');
  String get gallery => _t('Gallery', 'Galerie');
  String get working => _t('Working…', 'In Bearbeitung…');
  String get reEstimate => _t('Re-estimate', 'Neu schätzen');
  String get addServing => _t('Add serving', 'Portion hinzufügen');
  String get logMeal => _t('Log meal', 'Eintragen');
  String get resetMeal => _t('Reset', 'Zurücksetzen');
  String get readingPlate => _t('Analyzing the photo…', 'Foto wird ausgewertet…');
  String get lookingThatUp => _t('Looking that up…', 'Wird nachgeschlagen…');
  String get listening => _t('Listening… tap again to estimate.', 'Aufnahme läuft… erneut tippen zum Schätzen.');
  String get listeningShort => _t('Listening…', 'Aufnahme…');
  String get couldNotRecord => _t('Microphone unavailable.', 'Mikrofon nicht verfügbar.');
  String get couldNotOpenPhoto => _t('Could not open that photo.', 'Foto konnte nicht geöffnet werden.');
  String get nothingToLookUp => _t('Nothing to look up.', 'Nichts zum Nachschlagen.');
  String get weightAndEnergy => _t('Enter weight and calories first.', 'Zuerst Gewicht und Kalorien eintragen.');
  String get noMatchWriteSimpler => _t(
        'Use a simpler name, or enter energy manually.',
        'Einen einfacheren Namen verwenden oder die Energie selbst eintragen.',
      );
  String editIfOff(int totalKcal) => _t(
        'Adjust g or kcal/100g on a line if a value is off. $totalKcal kcal total.',
        'g oder kcal/100g in einer Zeile anpassen, wenn ein Wert nicht stimmt. $totalKcal kcal insgesamt.',
      );
  String get milkSweetnessQuestion => _t(
        'Unsweetened or sweetened milk? That can swing the calories a lot.',
        'Ungesüßte oder gesüßte Milch? Das ändert die kcal deutlich.',
      );
  String get unsweetenedMilk => _t('Unsweetened', 'Ungesüßt');
  String get sweetenedMilk => _t('Sweetened', 'Gesüßt');
  String get manualSource => _t('You', 'Du');
  String noMatchFor(String names) => _t(
        'No USDA / Open Food Facts match for $names. Weight is filled. Enter energy, or try a simpler name.',
        'Kein Treffer in USDA / Open Food Facts für $names. Das Gewicht ist gesetzt. Energie eintragen oder einen einfacheren Namen verwenden.',
      );
  String noMatchEnergyOnly(String names) => _t(
        'No match for $names. Energy is only the matched items.',
        'Kein Treffer für $names. Die Energie gilt nur für die erkannten Teile.',
      );
  String gramsNoMatch(int grams) => _t('${grams}g · no match', '${grams}g · kein Treffer');
  String get noMatchShort => _t('no match', 'kein Treffer');
  String lineSourceKcal(String source, int kcal) => _t('$source · $kcal kcal', '$source · $kcal kcal');
  String get looksFine => _t('Looks correct', 'Übernehmen');
  String get scoopWeightQuestion => _t(
        'How heavy is one scoop? That changes the calories a lot.',
        'Wie schwer ist ein Scoop? Das ändert die kcal deutlich.',
      );
  String get scoopCountQuestion => _t('One scoop or two?', 'Ein oder zwei Scoops?');
  String get oneScoop => _t('1 scoop', '1 Scoop');
  String get twoScoops => _t('2 scoops', '2 Scoops');
  String unmatchedShakeQuestion(String name) {
    final cleaned = name.trim();
    final short = cleaned.length > 32 ? '${cleaned.substring(0, 32)}…' : cleaned;
    return _t(
      'No match for $short. Powder or ready drink?',
      'Kein Treffer für $short. Pulver oder Fertigshake?',
    );
  }
  String get proteinPowder => _t('Powder', 'Pulver');
  String get readyShake => _t('Ready drink', 'Fertigshake');

  String lookupError(String raw) {
    final text = raw.replaceFirst('Bad state: ', '');
    if (text.contains('Gemini API key') || text.contains('settings')) {
      return _t(
        'Add a Gemini API key in settings. Calories still come from USDA / Open Food Facts.',
        'Lege in den Einstellungen einen Gemini-Schlüssel an. Kalorien kommen weiter von USDA / Open Food Facts.',
      );
    }
    if (text.contains('Write what it actually is')) {
      return _t('Describe what it actually is. Grams are optional.', 'Beschreibe, worum es sich handelt. Gramm sind optional.');
    }
    if (text.contains('No food was visible')) {
      return _t('Not enough food was visible to estimate.', 'Zu wenig Lebensmittel im Bild erkennbar.');
    }
    if (text.contains('could not read the photo')) {
      return _t('Gemini could not read the photo.', 'Gemini konnte das Foto nicht lesen.');
    }
    if (text.contains('Could not hear a meal') || text.contains('could not read that recording')) {
      return _t('Could not hear a meal in that recording.', 'In der Aufnahme war keine Mahlzeit zu hören.');
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
    if (text.contains('Failed to fetch') ||
        text.contains('openfoodfacts') ||
        text.contains('ClientException') ||
        text.contains('SocketException') ||
        text.contains('TimeoutException')) {
      return _t(
        'The food database was unreachable. Retry, or enter the energy manually.',
        'Die Lebensmittelsuche war nicht erreichbar. Erneut versuchen oder die Energie selbst eintragen.',
      );
    }
    return text;
  }

  String get yourJourney => _t('YOUR JOURNEY', 'DEIN VERLAUF');
  String get hideWeights => _t('Hide weight', 'Gewicht verbergen');
  String get showWeights => _t('Show weight', 'Gewicht zeigen');
  String get log => _t('Log', 'Eintragen');
  String get start => _t('Start', 'Start');
  String get now => _t('Now', 'Jetzt');
  String get change => _t('Change', 'Änderung');
  String get logToBeginLine => _t('Log a weigh-in to start the series.', 'Wiegeeintrag hinzufügen, um die Reihe zu starten.');
  String sinceDate(DateTime date) =>
      _t('Since ${monthShort(date.month)} ${date.day}', 'Seit ${date.day}. ${monthShort(date.month)}');
  String get firstWeighInHint => _t(
        'The first weigh-in becomes the start of the series.',
        'Der erste Wiegeeintrag wird zum Start der Reihe.',
      );
  String get lineStartsToday => _t('The series starts with today’s log.', 'Die Reihe beginnt mit dem heutigen Eintrag.');
  String get daysYouShowedUp => _t('DAYS YOU LOGGED', 'TAGE MIT EINTRAG');
  String get trackedDaysHint => _t(
        'Green: on target. Coral: over. Grey: nothing logged.',
        'Grün: im Ziel. Koralle: drüber. Grau: nichts eingetragen.',
      );
  String streakLabel(int days) {
    if (days <= 0) return _t('No streak yet', 'Noch keine Serie');
    if (days == 1) return _t('1-day streak', '1 Tag in Folge');
    return _t('$days-day streak', '$days Tage in Folge');
  }

  String streakChip(int days) {
    if (days <= 0) return streakLabel(days);
    if (days == 1) return _t('1 day', '1 Tag');
    return _t('$days days', '$days Tage');
  }

  String get ringClosed => _t('Target reached', 'Ziel erreicht');
  String get youClosedIt => _t('Daily target reached.', 'Tagesziel erreicht.');
  String get vsYesterday => _t('vs yesterday', 'vs. gestern');
  String get yesterdayGhost => _t('YESTERDAY', 'GESTERN');

  String get yourMoves => _t('FAVORITES', 'FAVORITEN');
  String get againThese => _t('AGAIN', 'NOCH MAL');
  String get tapToLog => _t('Tap to log.', 'Tippen zum Eintragen.');
  String get pinMeal => _t('Pin', 'Merken');
  String get pinned => _t('Pinned', 'Gemerkt');
  String get saveAsFavorite => _t('Save as a favorite', 'Als Favorit speichern');
  String get unnamedMeal => _t('Meal', 'Mahlzeit');
  String get removeFavorite => _t('Remove favorite?', 'Favorit entfernen?');
  String get removeFavoriteSubtitle => _t(
        'Removed from favorites. Today’s log is unchanged.',
        'Wird aus den Favoriten entfernt. Der heutige Eintrag bleibt.',
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
    switch (plan.mood) {
      case CoachMood.morningOpen:
        return plan.hasFill
            ? restFill(plan.remaining, fromFavorites: plan.fromFavorites)
            : _t(
                'Nothing logged yet.',
                'Noch nichts eingetragen.',
              );
      case CoachMood.closed:
        return restClosed();
      case CoachMood.over:
        return restOver(plan.remaining);
      case CoachMood.lateSip:
        return restSip(plan.remaining);
      case CoachMood.proteinPush:
      case CoachMood.dinner:
      case CoachMood.latePlate:
      case CoachMood.nextPlate:
        return plan.hasFill
            ? restFill(plan.remaining, fromFavorites: plan.fromFavorites)
            : restOpen(plan.remaining);
    }
  }

  String restClosed() => _t(
        'Daily target reached.',
        'Tagesziel erreicht.',
      );
  String restOver(int extra) => _t(
        '$extra kcal over target.',
        '$extra kcal über dem Ziel.',
      );
  String restOpen(int left) => _t(
        '$left kcal still open.',
        'Noch $left kcal offen.',
      );
  String restFill(int left, {bool fromFavorites = true}) => fromFavorites
      ? _t(
          '$left kcal left. From your favorites:',
          'Noch $left kcal. Aus deinen Favoriten:',
        )
      : _t(
          '$left kcal left. From meals you already logged:',
          'Noch $left kcal. Aus deinen Gerichten:',
        );
  String restTogether(int filled, int leftover) {
    if (leftover <= 0) {
      return _t('Together $filled kcal.', 'Zusammen $filled kcal.');
    }
    return _t(
      'Together $filled · $leftover still open',
      'Zusammen $filled · noch $leftover offen',
    );
  }
  String servingsOf(String name, int servings) =>
      servings <= 1 ? name : '$name ×$servings';
  String restSip(int left) => _t(
        '$left kcal left — more a drink than a meal.',
        'Noch $left kcal — eher ein Getränk als eine Mahlzeit.',
      );
  String restFits(int left, String a, String? b) {
    if (b == null || b.isEmpty) {
      return _t(
        '$left kcal left. Fits $a.',
        'Noch $left kcal. Passt zu $a.',
      );
    }
    return _t(
      '$left kcal left. Fits $a or $b.',
      'Noch $left kcal. Passt zu $a oder $b.',
    );
  }

  String get microGoals => _t("TODAY'S GOALS", 'TAGESZIELE');
  String get microGoalsThatDay => _t("THAT DAY'S GOALS", 'ZIELE DES TAGES');
  String ringsClosed(int n) => n == 1
      ? _t('1 goal reached', '1 Ziel erreicht')
      : _t('$n goals reached', '$n Ziele erreicht');
  String get breakfastGoal => _t('Breakfast', 'Frühstück');
  String get proteinGoal => _t('Protein', 'Protein');
  String get noLateGoal => _t('No late meal', 'Kein spätes Essen');
  String proteinGoalLine(int grams, int target) =>
      _t('$grams / $target g', '$grams / $target g');

  String get weekOnYourPlate => _t('THIS WEEK', 'DIESE WOCHE');
  String get swipeTheWeek => _t('Swipe through the week', 'Woche durchblättern');

  String get snapAPlate => _t('Take a photo', 'Foto machen');
  String logThisPlate(int kcal) => _t('Log this plate · $kcal kcal', 'Teller eintragen · $kcal kcal');
  String get lookingAtThePlate => _t(
        'The photo is stored in the log. Estimate is optional.',
        'Das Foto bleibt im Tagebuch. Die Schätzung ist optional.',
      );

  String trendLabel(GoalType goal, double plannedKgPerWeek) {
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
    if (plannedKgPerWeek < 0.05) {
      switch (goal) {
        case GoalType.lose:
          return loseHint;
        case GoalType.gain:
          return gainHint;
        case GoalType.maintain:
          return _t('Keeping this weight', 'Dieses Gewicht halten');
      }
    }
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
      case PaceHint.holdUpMuch:
        return _t(
          'Well above the start. The goal is still to maintain.',
          'Deutlich über dem Startgewicht. Das Ziel bleibt Halten.',
        );
      case PaceHint.holdDownMuch:
        return _t(
          'Well below the start. The goal is still to maintain.',
          'Deutlich unter dem Startgewicht. Das Ziel bleibt Halten.',
        );
      case PaceHint.onPace:
        return _t('You are on track.', 'Du liegst im Plan.');
      case PaceHint.ahead:
        return _t('A bit ahead of the plan.', 'Etwas vor dem Plan.');
      case PaceHint.aheadMuch:
        return _t('Well ahead of the plan.', 'Deutlich vor dem Plan.');
      case PaceHint.behind:
        return _t('A bit behind the plan.', 'Etwas hinter dem Plan.');
      case PaceHint.behindMuch:
        return _t('Well behind the plan.', 'Deutlich hinter dem Plan.');
    }
  }

  String onDate(DateTime date) =>
      _t('On ${date.day}.${date.month}.${date.year}', 'Am ${date.day}.${date.month}.${date.year}');
  String get orTypeIt => _t('Or type it', 'Oder tippen');
  String get exampleKcal => _t('e.g. 2200', 'z. B. 2200');
  String get kgPerWeekShort => _t('kg/wk', 'kg/Wo');
  String get saveWeighIn => _t('Save this weigh-in', 'Diesen Eintrag speichern');

  String get gentleHelpers => _t('NOTES', 'HINWEISE');
  String get gentleHelpersSubtitle => _t(
        'Practical levers for a deficit. No miracle products.',
        'Praktikable Hebel für ein Defizit. Keine Wundermittel.',
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
        return _t('Accurate portions', 'Präzise Portionen');
      case LossHelper.protein:
        return _t('Satiety', 'Sättigung');
      case LossHelper.water:
        return _t('Low-kcal swap', 'Kalorienarmer Ersatz');
      case LossHelper.volume:
        return _t('High volume', 'Hohes Volumen');
      case LossHelper.walk:
        return _t('No gym required', 'Ohne Studio');
    }
  }

  String lossWhy(LossHelper id) {
    switch (id) {
      case LossHelper.scale:
        return _t(
          'A kitchen scale removes guesswork. “A handful” is usually heavier than it looks.',
          'Eine Küchenwaage ersetzt Schätzungen. Eine „Handvoll“ wiegt meist mehr, als sie aussieht.',
        );
      case LossHelper.protein:
        return _t(
          'Eggs, Greek yogurt, quark, tofu, fish. Higher protein improves satiety and makes a deficit easier to hold.',
          'Eier, griechischer Joghurt, Quark, Tofu, Fisch. Mehr Protein verbessert die Sättigung und macht ein Defizit haltbarer.',
        );
      case LossHelper.water:
        return _t(
          'A large glass before a meal, or instead of a sweet drink, often cuts a few hundred kcal.',
          'Ein großes Glas vor der Mahlzeit — oder statt eines süßen Getränks — spart oft mehrere hundert kcal.',
        );
      case LossHelper.volume:
        return _t(
          'Broth, berries, cucumber, large salads: high volume at low energy density.',
          'Brühe, Beeren, Gurke, große Salate: viel Volumen bei niedriger Energiedichte.',
        );
      case LossHelper.walk:
        return _t(
          'Twenty minutes of walking raises expenditure without a gym session.',
          'Zwanzig Minuten Gehen erhöhen den Verbrauch, ohne Trainingseinheit.',
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
  String get yesterday => _t('Yesterday', 'Gestern');
  String get dayBeforeYesterday => _t('The day before', 'Vorgestern');
  String daysAgo(int days) => days == 1
      ? _t('1 day ago', 'Vor 1 Tag')
      : _t('$days days ago', 'Vor $days Tagen');
  String get tomorrow => _t('Tomorrow', 'Morgen');
  String get dayAfterTomorrow => _t('The day after', 'Übermorgen');
  String inDays(int days) => days == 1
      ? _t('In 1 day', 'In 1 Tag')
      : _t('In $days days', 'In $days Tagen');

  String relativeDay(DateTime date, {DateTime? now}) {
    final origin = now ?? DateTime.now();
    final todayDate = DateTime(origin.year, origin.month, origin.day);
    final day = DateTime(date.year, date.month, date.day);
    final delta = day.difference(todayDate).inDays;
    if (delta == 0) return today;
    if (delta == -1) return yesterday;
    if (delta == -2) return dayBeforeYesterday;
    if (delta < 0) return daysAgo(-delta);
    if (delta == 1) return tomorrow;
    if (delta == 2) return dayAfterTomorrow;
    return inDays(delta);
  }
  String weekLabel(int week) => _t('Week $week', 'Woche $week');
  String daysOfSeven(int n) => _t('$n / 7 days', '$n / 7 Tage');
  String avgKcal(int kcal) => _t('Ø $kcal kcal', 'Ø $kcal kcal');
  String get thisWeek => _t('This week', 'Diese Woche');
  String get emptyWeek => _t('Nothing logged', 'Keine Einträge');
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

  String get dayEmpty => _t('Nothing logged this day.', 'Keine Einträge an diesem Tag.');

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
  String versionOnly(String version) => _t('v$version', 'v$version');
  String versionCurrent(String version) =>
      _t('v$version · up to date', 'v$version · aktuell');
  String versionUpdate(String current, String latest) =>
      _t('v$current · update $latest', 'v$current · Update $latest');

  String get backupTitle => _t('Backup', 'Sicherung');
  String get backupSubtitle => _t(
        'Same backup file, two places: your device or Google Drive. Restore from either.',
        'Dieselbe Backup-Datei, zwei Orte: Gerät oder Google Drive. Wiederherstellen geht von beiden.',
      );
  String get backupLast => _t('LAST BACKUP', 'LETZTES BACKUP');
  String get backupNever => _t('Never backed up', 'Noch kein Backup');
  String get backupIncludePhotos => _t('Include meal photos', 'Essensfotos einschließen');
  String get backupIncludePhotosHint => _t(
        'Photos make the file larger, like videos in WhatsApp.',
        'Fotos machen die Datei größer — wie Videos bei WhatsApp.',
      );
  String get backupNow => _t('Download file', 'Datei herunterladen');
  String get backupToDrive => _t('Save to Google Drive', 'In Google Drive');
  String get backupRestore => _t('From file', 'Von Datei');
  String get backupRestoreFromDrive => _t('From Google Drive', 'Von Google Drive');
  String get backupRestoreSection => _t('RESTORE', 'WIEDERHERSTELLEN');
  String get backupSaveTitle => _t('Save backup file', 'Backup-Datei speichern');
  String get backupRestoreTitle => _t('Replace all data?', 'Alle Daten ersetzen?');
  String get backupRestoreSubtitle => _t(
        'Current meals, weight and settings are replaced by the backup.',
        'Aktuelle Mahlzeiten, Gewicht und Einstellungen werden durch das Backup ersetzt.',
      );
  String get backupRestoreConfirm => _t('Insert backup', 'Backup einfügen');
  String get backupSaved => _t('File downloaded', 'Datei gespeichert');
  String get backupSavedSubtitle => _t(
        'The file is in your downloads. Use From file when you want it back.',
        'Die Datei liegt in den Downloads. Über „Von Datei“ wiederherstellen.',
      );
  String get backupSavedDrive => _t('Ready for Drive', 'Bereit für Drive');
  String get backupSavedDriveSubtitle => _t(
        'Upload the downloaded file to Google Drive. Restore it later with From Google Drive.',
        'Lade die heruntergeladene Datei in Google Drive hoch. Später über „Von Google Drive“ zurückholen.',
      );
  String get backupPickFile => _t('Choose the backup file', 'Backup-Datei wählen');
  String get backupPickDrive => _t(
        'Download the backup from Drive, then choose that file.',
        'Backup in Drive herunterladen, dann diese Datei wählen.',
      );
  String get backupRestored => _t('Backup restored', 'Backup wiederhergestellt');
  String backupRestoredSubtitle(int meals) => meals == 1
      ? _t('1 meal is back.', '1 Mahlzeit ist wieder da.')
      : _t('$meals meals are back.', '$meals Mahlzeiten sind wieder da.');
  String get backupFailed => _t('Backup failed', 'Backup fehlgeschlagen');
  String get backupInvalid => _t(
        'This file is not a calorie tracker backup.',
        'Diese Datei ist kein Kalorien-Backup.',
      );
  String get backupCanceled => _t('Backup canceled', 'Backup abgebrochen');
  String get backupBusy => _t('Working on it…', 'Einen Moment…');

  String backupBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String backupLastLine(DateTime date, int bytes) {
    final when = '${prettyDate(date)}, ${clock(date)}';
    if (bytes <= 0) return when;
    return '$when · ${backupBytes(bytes)}';
  }

  String backupInventory(BackupCounts counts) {
    final meals = counts.meals == 1
        ? _t('1 meal', '1 Mahlzeit')
        : _t('${counts.meals} meals', '${counts.meals} Mahlzeiten');
    final photos = counts.photos == 1
        ? _t('1 photo', '1 Foto')
        : _t('${counts.photos} photos', '${counts.photos} Fotos');
    final weights = counts.weights == 1
        ? _t('1 weigh-in', '1 Wiegeeintrag')
        : _t('${counts.weights} weigh-ins', '${counts.weights} Wiegeeinträge');
    return '$meals · $photos · $weights';
  }
}

enum LossHelper { scale, protein, water, volume, walk }
