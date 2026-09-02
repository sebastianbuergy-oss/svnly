import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:svnly/app/splash_screen.dart';
import 'package:svnly/core/config/app_config.dart';

void main() {
  testWidgets(
    'splash defers its initial redirect until after the first frame',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
          GoRoute(
            path: '/configuration',
            builder: (_, _) => const Scaffold(body: Text('configuration')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                environment: AppEnvironment.local,
                supabaseUrl: '',
                supabasePublishableKey: '',
                revenueCatIosApiKey: '',
                premiumReleaseEnabled: false,
                legalBaseUrl: 'https://svnly.app',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('configuration'), findsOneWidget);
    },
  );
}
