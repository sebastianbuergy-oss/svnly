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
import 'package:svnly/core/design/tokens.dart';
import 'package:svnly/features/auth/app_repository.dart';
import 'package:svnly/features/auth/auth_screen.dart';
import 'package:svnly/features/challenge/home_screen.dart';
import 'package:svnly/features/challenge/models.dart';
import 'package:svnly/features/onboarding/onboarding_screen.dart';
import 'package:svnly/features/ranking/ranking_screen.dart';

class ScreenshotRepository extends Mock implements AppRepository {}

Widget _todayScreen() => Scaffold(
  body: const HomeScreen(),
  bottomNavigationBar: NavigationBar(
    selectedIndex: 0,
    destinations: [
      NavigationDestination(icon: Icon(Icons.home), label: 'Today'),
      NavigationDestination(icon: Icon(Icons.play_circle), label: 'Discover'),
      NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Ranking'),
      NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
    ],
  ),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture store-ready screens from the running iOS app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = ScreenshotRepository();
    when(() => repository.currentChallenge()).thenAnswer(
      (_) async => DailyChallenge(
        id: 'review-challenge',
        challengeDate: DateTime.utc(2026, 8, 21),
        titleEn: 'Show us your hidden talent.',
        titleDe: 'Zeig uns dein verstecktes Talent.',
        descriptionEn: 'Seven seconds. No edits. Make it count.',
        descriptionDe: 'Sieben Sekunden. Keine Bearbeitung.',
        category: 'CREATIVE',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        participantCount: 1842,
      ),
    );
    when(() => repository.hasTakeToday()).thenAnswer((_) async => false);
    when(() => repository.loadRankings(any(), any())).thenAnswer(
      (_) async => const [
        {
          'rank': 1,
          'display_name': 'Maya Chen',
          'username': 'maya.real',
          'country_code': 'CH',
          'score': 982,
        },
        {
          'rank': 2,
          'display_name': 'Noah Williams',
          'username': 'noahseven',
          'country_code': 'GB',
          'score': 941,
        },
        {
          'rank': 3,
          'display_name': 'Sofia Rossi',
          'username': 'sofia.rossi',
          'country_code': 'IT',
          'score': 910,
        },
        {
          'rank': 4,
          'display_name': 'Lina Berger',
          'username': 'lina.raw',
          'country_code': 'DE',
          'score': 886,
        },
      ],
    );

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
        GoRoute(path: '/home', builder: (_, _) => _todayScreen()),
        GoRoute(path: '/ranking', builder: (_, _) => const RankingScreen()),
      ],
    );
    addTearDown(router.dispose);
    final screen = ValueNotifier<Widget>(const SvnlyApp());
    addTearDown(screen.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          routerProvider.overrideWithValue(router),
        ],
        child: ValueListenableBuilder<Widget>(
          valueListenable: screen,
          builder: (_, value, _) => value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-one-challenge');

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-seven-seconds');

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-no-peeking');

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-be-real');

    screen.value = MaterialApp(
      theme: buildSvnlyTheme(),
      home: _todayScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('05-today-challenge');

    screen.value = MaterialApp(
      theme: buildSvnlyTheme(),
      home: const RankingScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('06-ranking');
  });
}
