import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:svnly/app/providers.dart';
import 'package:svnly/core/design/tokens.dart';
import 'package:svnly/features/auth/app_repository.dart';
import 'package:svnly/features/profile/edit_profile_screen.dart';

class _MockRepository extends Mock implements AppRepository {}

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  Widget harness(EditProfileScreen screen, AppRepository repository) =>
      ProviderScope(
        overrides: [appRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(theme: buildSvnlyTheme(), home: screen),
      );

  Map<String, dynamic> profile({String? avatarPath}) => {
    'username': 'seven.real',
    'display_name': 'Seven',
    'bio': 'Lowkey iconic.',
    'country_code': 'CH',
    'avatar_path': avatarPath,
  };

  testWidgets(
    'profile camera action prefers the front camera, processes and uploads',
    (tester) async {
      final repository = _MockRepository();
      when(repository.loadMyProfile).thenAnswer((_) async => profile());
      when(() => repository.uploadAvatar(any()))
          .thenAnswer((_) async => 'user/avatar-new.jpg');
      when(
        () => repository.updateProfile(
          username: any(named: 'username'),
          displayName: any(named: 'displayName'),
          bio: any(named: 'bio'),
          countryCode: any(named: 'countryCode'),
          avatarPath: any(named: 'avatarPath'),
          removeAvatar: any(named: 'removeAvatar'),
        ),
      ).thenAnswer((_) async {});

      ImageSource? requestedSource;
      CameraDevice? requestedCamera;
      final sourceImage = image.Image(width: 900, height: 1200);
      image.fill(sourceImage, color: image.ColorRgb8(0, 230, 255));
      await tester.pumpWidget(
        harness(
          EditProfileScreen(
            avatarPicker: (source, camera) async {
              requestedSource = source;
              requestedCamera = camera;
              return Uint8List.fromList(image.encodePng(sourceImage));
            },
          ),
          repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pick_profile_avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Foto aufnehmen'), findsOneWidget);
      expect(find.text('Aus Galerie wählen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('take_profile_photo')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 750)),
      );
      await tester.pumpAndSettle();

      expect(requestedSource, ImageSource.camera);
      expect(requestedCamera, CameraDevice.front);
      final avatar = tester.widget<CircleAvatar>(
        find.byKey(const ValueKey('edit_profile_avatar')),
      );
      expect(avatar.backgroundImage, isA<MemoryImage>());

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save_profile_changes')),
      );
      await tester.tap(find.byKey(const ValueKey('save_profile_changes')));
      await tester.pump();

      final upload = verify(() => repository.uploadAvatar(captureAny()));
      upload.called(1);
      final uploadedBytes = upload.captured.single as Uint8List;
      final decoded = image.decodeJpg(uploadedBytes);
      expect(decoded?.width, 768);
      expect(decoded?.height, 768);
      verify(
        () => repository.updateProfile(
          username: 'seven.real',
          displayName: 'Seven',
          bio: 'Lowkey iconic.',
          countryCode: 'CH',
          avatarPath: 'user/avatar-new.jpg',
          removeAvatar: false,
        ),
      ).called(1);
    },
  );

  testWidgets('profile picture removal is explicit and persists via the RPC', (
    tester,
  ) async {
    final repository = _MockRepository();
    when(repository.loadMyProfile)
        .thenAnswer((_) async => profile(avatarPath: 'user/avatar-old.jpg'));
    when(
      () => repository.updateProfile(
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        bio: any(named: 'bio'),
        countryCode: any(named: 'countryCode'),
        avatarPath: any(named: 'avatarPath'),
        removeAvatar: any(named: 'removeAvatar'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(harness(const EditProfileScreen(), repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pick_profile_avatar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remove_profile_photo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove_profile_photo')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save_profile_changes')),
    );
    await tester.tap(find.byKey(const ValueKey('save_profile_changes')));
    await tester.pump();

    verifyNever(() => repository.uploadAvatar(any()));
    verify(
      () => repository.updateProfile(
        username: 'seven.real',
        displayName: 'Seven',
        bio: 'Lowkey iconic.',
        countryCode: 'CH',
        avatarPath: null,
        removeAvatar: true,
      ),
    ).called(1);
  });
}
