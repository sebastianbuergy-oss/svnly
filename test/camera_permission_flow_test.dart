import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/core/localization/app_strings.dart';
import 'package:svnly/features/camera/camera_policy.dart';
import 'package:svnly/features/camera/camera_screen.dart';

Widget _harness(
  Locale locale, {
  Future<CapturePermissionState> Function()? statusReader,
  Future<CapturePermissionState> Function()? requester,
  Future<bool> Function()? openSettings,
}) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('de')],
    localizationsDelegates: const [
      AppStringsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: CameraScreen(
      permissionStatusReader: statusReader,
      permissionRequester: requester,
      openSettings: openSettings,
    ),
  ),
);

void main() {
  testWidgets('camera permission pre-prompt uses neutral English action', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('ENABLE'), findsNothing);
    expect(find.textContaining('ALLOW'), findsNothing);
    expect(find.textContaining('GRANT'), findsNothing);
  });

  testWidgets('camera permission pre-prompt uses neutral German action', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Weiter'), findsOneWidget);
    expect(find.textContaining('AKTIVIEREN'), findsNothing);
    expect(find.textContaining('ERLAUBEN'), findsNothing);
  });

  testWidgets('denied permission becomes stable Settings recovery', (
    tester,
  ) async {
    var requestCount = 0;
    var settingsCount = 0;
    await tester.pumpWidget(
      _harness(
        const Locale('en'),
        statusReader: () async => CapturePermissionState.requestable,
        requester: () async {
          requestCount++;
          return CapturePermissionState.requiresSettings;
        },
        openSettings: () async {
          settingsCount++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('continue_to_camera_permissions')),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.textContaining('server verifies'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open_camera_settings')));
    await tester.pump();
    expect(settingsCount, 1);
  });

  testWidgets('previous denial never requests permission again', (
    tester,
  ) async {
    var requestCount = 0;
    await tester.pumpWidget(
      _harness(
        const Locale('en'),
        statusReader: () async => CapturePermissionState.requiresSettings,
        requester: () async {
          requestCount++;
          return CapturePermissionState.granted;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('continue_to_camera_permissions')),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 0);
    expect(find.text('Open Settings'), findsOneWidget);
  });
}
