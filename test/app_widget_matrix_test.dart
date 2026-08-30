import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:svnly/app/providers.dart';
import 'package:svnly/core/design/tokens.dart';
import 'package:svnly/core/localization/app_strings.dart';
import 'package:svnly/features/auth/app_repository.dart';
import 'package:svnly/features/auth/auth_screen.dart';
import 'package:svnly/features/challenge/home_screen.dart';
import 'package:svnly/features/challenge/models.dart';
import 'package:svnly/features/ranking/ranking_screen.dart';
import 'package:svnly/features/settings/settings_details.dart';

class MockRepository extends Mock implements AppRepository {}

Widget harness(
  Widget child,
  MockRepository repository, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [appRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      theme: buildSvnlyTheme(),
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: child,
    ),
  );
}

void main() {
  late MockRepository repository;

  setUp(() => repository = MockRepository());

  group('authentication widgets', () {
    testWidgets('production login exposes Google, Apple and build identity', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const AuthScreen(), repository));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth_google')), findsOneWidget);
      expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_apple')), findsOneWidget);
      expect(find.byKey(const ValueKey('build_identity')), findsOneWidget);
    });

    testWidgets('invalid credentials are rejected before repository call', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const AuthScreen(), repository));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth_email')),
        'invalid',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_password')),
        'short',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('auth_submit')));
      await tester.tap(find.text('LOG IN'));
      await tester.pump();
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(find.text('Use at least 10 characters.'), findsOneWidget);
      verifyNever(() => repository.signIn(any(), any()));
    });

    testWidgets(
      'sign-up submits normalized form state and shows verification state',
      (tester) async {
        when(() => repository.signUp(any(), any())).thenAnswer((_) async {});
        await tester.pumpWidget(
          harness(const AuthScreen(initialSignUp: true), repository),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('auth_email')),
          'reviewer@svnly.app',
        );
        await tester.enterText(
          find.byKey(const ValueKey('auth_password')),
          'StrongPass!42',
        );
        await tester.ensureVisible(find.byKey(const ValueKey('auth_submit')));
        await tester.tap(find.byKey(const ValueKey('auth_submit')));
        await tester.pumpAndSettle();
        verify(() => repository.signUp('reviewer@svnly.app', 'StrongPass!42'))
            .called(1);
        expect(find.text('Check your inbox.'), findsOneWidget);
        expect(find.textContaining('reviewer@svnly.app'), findsOneWidget);
      },
    );
  });

  group('challenge widgets', () {
    final challenge = DailyChallenge(
      id: 'challenge-1',
      challengeDate: DateTime.utc(2026, 8, 21),
      titleEn: 'Show something unmistakably real.',
      titleDe: 'Zeig etwas unverkennbar Echtes.',
      descriptionEn: 'One safe take.',
      descriptionDe: 'Ein sicherer Take.',
      category: 'everyday',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      participantCount: 27,
    );

    testWidgets(
      'home renders the active English challenge and unlocked capture CTA',
      (tester) async {
        when(() => repository.currentChallenge())
            .thenAnswer((_) async => challenge);
        when(() => repository.hasTakeToday()).thenAnswer((_) async => false);
        await tester.pumpWidget(harness(const HomeScreen(), repository));
        await tester.pump();
        await tester.pump();
        expect(find.text('Show something unmistakably real.'), findsOneWidget);
        expect(find.text('TAKE YOUR 7 SECONDS'), findsOneWidget);
        expect(find.text('27 takes today'), findsOneWidget);
      },
    );

    testWidgets(
      'home localizes challenge and locks repeat capture after completion',
      (tester) async {
        when(() => repository.currentChallenge())
            .thenAnswer((_) async => challenge);
        when(() => repository.hasTakeToday()).thenAnswer((_) async => true);
        await tester.pumpWidget(
          harness(const HomeScreen(), repository, locale: const Locale('de')),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Zeig etwas unverkennbar Echtes.'), findsOneWidget);
        expect(find.text('DONE ✓'), findsOneWidget);
        expect(find.text('NIMM DEINE 7 SEKUNDEN AUF'), findsNothing);
      },
    );

    testWidgets('home exposes a retry state when challenge loading fails', (
      tester,
    ) async {
      when(() => repository.currentChallenge())
          .thenThrow(StateError('offline'));
      when(() => repository.hasTakeToday()).thenAnswer((_) async => false);
      await tester.pumpWidget(harness(const HomeScreen(), repository));
      await tester.pump();
      await tester.pump();
      expect(find.text('Challenge unavailable'), findsOneWidget);
      expect(find.text('TRY AGAIN'), findsOneWidget);
    });
  });

  group('privacy and notification widgets', () {
    testWidgets(
      'enabling product news registers APNs before persisting preference',
      (tester) async {
        when(() => repository.registerForPush(promptIfNeeded: true))
            .thenAnswer((_) async => true);
        when(() => repository.updateSetting(any(), any()))
            .thenAnswer((_) async {});
        await tester.pumpWidget(
          harness(const NotificationSettingsScreen(), repository),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('notification_product_news_push')),
        );
        await tester.pumpAndSettle();
        verifyInOrder([
          () => repository.registerForPush(promptIfNeeded: true),
          () => repository.updateSetting('product_news_push', true),
        ]);
      },
    );

    testWidgets(
      'denied APNs permission does not enable or persist a category',
      (tester) async {
        when(() => repository.registerForPush(promptIfNeeded: true))
            .thenAnswer((_) async => false);
        await tester.pumpWidget(
          harness(const NotificationSettingsScreen(), repository),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('notification_product_news_push')),
        );
        await tester.pumpAndSettle();
        verifyNever(() => repository.updateSetting(any(), any()));
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('notification_product_news_push')),
              )
              .value,
          false,
        );
      },
    );

    testWidgets('privacy controls persist private profile and retention', (
      tester,
    ) async {
      when(() => repository.updateSetting(any(), any()))
          .thenAnswer((_) async {});
      await tester.pumpWidget(
        harness(const PrivacySettingsScreen(), repository),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('privacy_private_profile')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Keep until I delete'), 200);
      await tester.tap(find.text('Keep until I delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After 90 days').last);
      await tester.pumpAndSettle();
      verify(() => repository.updateSetting('is_private', true)).called(1);
      verify(() => repository.updateSetting('auto_delete_days', 90)).called(1);
    });
  });

  testWidgets('about exposes the signed build number and commit identity', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const AboutScreen(), repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about_build_identity')), findsOneWidget);
    expect(find.text('Build local · developm'), findsOneWidget);
  });

  group('ranking widgets', () {
    testWidgets('ranking renders authoritative rank and score', (tester) async {
      when(() => repository.loadRankings(any(), any())).thenAnswer(
        (_) async => [
          {
            'rank': 1,
            'display_name': 'Ada',
            'username': 'ada.real',
            'country_code': 'CH',
            'score': 98.5,
          },
        ],
      );
      await tester.pumpWidget(harness(const RankingScreen(), repository));
      await tester.pumpAndSettle();
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('@ada.real · CH'), findsOneWidget);
      expect(find.text('98.5'), findsOneWidget);
    });

    testWidgets('ranking period switch reloads all-time world results', (
      tester,
    ) async {
      when(() => repository.loadRankings(any(), any()))
          .thenAnswer((_) async => []);
      await tester.pumpWidget(harness(const RankingScreen(), repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALL TIME'));
      await tester.pumpAndSettle();
      verify(() => repository.loadRankings('all_time', 'world')).called(1);
      expect(find.text('The world is still waking up.'), findsOneWidget);
    });
  });
}
