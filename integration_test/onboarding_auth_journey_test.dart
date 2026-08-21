import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svnly/app/providers.dart';
import 'package:svnly/app/router.dart';
import 'package:svnly/app/svnly_app.dart';
import 'package:svnly/features/auth/app_repository.dart';
import 'package:svnly/features/auth/auth_screen.dart';
import 'package:svnly/features/onboarding/onboarding_screen.dart';

class JourneyRepository extends Mock implements AppRepository {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new user completes onboarding and requests an account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = JourneyRepository();
    when(() => repository.signUp(any(), any())).thenAnswer((_) async {});
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, state) => AuthScreen(
            initialSignUp: state.uri.queryParameters['mode'] == 'signup',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          routerProvider.overrideWithValue(router),
        ],
        child: const SvnlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (var page = 0; page < 3; page++) {
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
    }
    expect(find.text('JOIN SVNLY'), findsOneWidget);
    await tester.tap(find.text('JOIN SVNLY'));
    await tester.pumpAndSettle();
    expect(find.text('Join the real ones.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('auth_email')),
      'appreview+primary@svnly.app',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_password')),
      'ReviewReady!42',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final submitButton = find.byKey(const ValueKey('auth_submit'));
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    verify(
      () => repository.signUp('appreview+primary@svnly.app', 'ReviewReady!42'),
    ).called(1);
    expect(find.text('Check your inbox.'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_complete'), true);
  });
}
