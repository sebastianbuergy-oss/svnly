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
  String get locked => isGerman
      ? 'Mach zuerst deinen Take, bevor du die anderen siehst.'
      : 'Take yours before you see theirs.';
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
