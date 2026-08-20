import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svnly/core/localization/app_strings.dart';
import 'package:svnly/features/onboarding/onboarding_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onboarding explains the daily challenge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppStringsDelegate()],
        supportedLocales: [Locale('en'), Locale('de')],
        home: OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('One challenge. Every day.'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('SVNLY'), findsNothing);
  });
}
