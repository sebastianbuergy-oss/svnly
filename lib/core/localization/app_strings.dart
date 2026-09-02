import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;
  bool get isGerman => locale.languageCode == 'de';

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  String get claim => '7 seconds. One take. Be real.';
  String get join => isGerman ? 'SVNLY BEITRETEN' : 'JOIN SVNLY';
  String get login => isGerman ? 'ANMELDEN' : 'LOG IN';
  String get today => isGerman ? 'HEUTIGES SVNLY' : "TODAY'S SVNLY";
  String get take =>
      isGerman ? 'NIMM DEINE 7 SEKUNDEN AUF' : 'TAKE YOUR 7 SECONDS';
  String get takeTease => isGerman
      ? 'Nicht overthinken. Einfach posten. 👀'
      : "Don't overthink it. Just post. 👀";
  String get lockedTitle => isGerman ? 'NICHT SPICKEN 👀' : 'NO PEEKING 👀';
  String get locked => isGerman
      ? 'Erst selber liefern. 7 Sekunden. Kein Film schieben.'
      : 'Drop your 7 seconds first. No lurking.';
  String get successTitle => 'YOU ATE 🔥';
  String get successBody => isGerman
      ? 'Lowkey iconic. Jetzt schau, was die anderen geliefert haben.'
      : 'Lowkey iconic. Now see what everyone else delivered.';
  String get flexIt => isGerman ? "ZEIG'S IHNEN" : 'FLEX IT';
  String get offline => isGerman
      ? 'Du bist offline. Dein Take wird hochgeladen, sobald du wieder online bist.'
      : "You're offline. Your take will upload when you're back.";
  String get moderation => isGerman
      ? 'Wir prüfen deinen Take, bevor er live geht.'
      : "We're checking your take before it goes live.";
  String get noFriends => isGerman
      ? 'Bei deinen Freunden ist es ruhig. Finde jemanden Echtes.'
      : 'Your friends feed is quiet. Find someone real.';
  String get noRanking => isGerman
      ? 'Die Welt wacht gerade erst auf.'
      : 'The world is still waking up.';
  String get permissionContinue => isGerman ? 'Weiter' : 'Continue';
  String get cameraPermissionTitle =>
      isGerman ? 'Deine Kamera. Dein Moment.' : 'Your camera. Your moment.';
  String get cameraPermissionExplanation => isGerman
      ? 'SVNLY benötigt Kamera und Mikrofon nur für deinen 7-Sekunden-Take. '
            'Nach „Weiter“ zeigt iOS die Systemabfragen. Dort entscheidest du '
            'selbst über den Zugriff.'
      : 'SVNLY needs the camera and microphone only for your seven-second '
            'Take. After Continue, iOS shows the system prompts, where you '
            'decide whether to provide access.';
  String get cameraPermissionDenied => isGerman
      ? 'Ohne Kamera- und Mikrofonzugriff kann SVNLY keinen 7-Sekunden-Take '
            'aufnehmen. Du kannst deine Auswahl in den iOS-Einstellungen ändern.'
      : 'SVNLY cannot record a seven-second Take without camera and microphone '
            'access. You can change your choice in iOS Settings.';
  String get openSettings =>
      isGerman ? 'Einstellungen öffnen' : 'Open Settings';
  String get backToToday => isGerman ? 'ZURÜCK ZU TODAY' : 'BACK TO TODAY';
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'de', 'en'}.contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
