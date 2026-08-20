import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/core/localization/app_strings.dart';

void main() {
  test('German and English strings preserve the product rules', () {
    const german = AppStrings(Locale('de'));
    const english = AppStrings(Locale('en'));

    expect(german.take, contains('7 SEKUNDEN'));
    expect(german.locked, contains('zuerst'));
    expect(english.take, contains('7 SECONDS'));
    expect(english.claim, '7 seconds. One take. Be real.');
  });

  test('delegate supports only shipped locales', () {
    const delegate = AppStringsDelegate();
    expect(delegate.isSupported(const Locale('de')), isTrue);
    expect(delegate.isSupported(const Locale('en')), isTrue);
    expect(delegate.isSupported(const Locale('fr')), isFalse);
  });
}
