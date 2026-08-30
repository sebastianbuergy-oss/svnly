import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/features/camera/camera_policy.dart';

void main() {
  const cameras = [
    CameraDescription(
      name: 'back-telephoto',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
      lensType: CameraLensType.telephoto,
    ),
    CameraDescription(
      name: 'back-ultra-wide',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
      lensType: CameraLensType.ultraWide,
    ),
    CameraDescription(
      name: 'front-wide',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
      lensType: CameraLensType.wide,
    ),
    CameraDescription(
      name: 'back-wide',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
      lensType: CameraLensType.wide,
    ),
  ];

  test('the normal wide rear camera wins over telephoto and ultra-wide', () {
    final index = naturalCameraIndex(cameras, CameraLensDirection.back);
    expect(cameras[index].name, 'back-wide');
  });

  test('camera flip selects the natural wide front camera', () {
    final index = naturalCameraIndex(cameras, CameraLensDirection.front);
    expect(cameras[index].name, 'front-wide');
  });

  test(
    'camera startup explicitly applies native 1.0x and never more',
    () async {
      double? appliedZoom;
      await applyNaturalStartupZoom(
        getMinZoom: () async => 1,
        getMaxZoom: () async => 8,
        setZoom: (zoom) async => appliedZoom = zoom,
      );
      expect(appliedZoom, naturalCameraZoom);
      expect(appliedZoom, 1.0);
      expect(appliedZoom, isNot(greaterThan(1.0)));
    },
  );

  test('startup fails closed if a device cannot expose native 1.0x', () async {
    expect(
      () => applyNaturalStartupZoom(
        getMinZoom: () async => 2,
        getMaxZoom: () async => 8,
        setZoom: (_) async {},
      ),
      throwsStateError,
    );
  });

  testWidgets('preview contains the full portrait camera aspect ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(450, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: NaturalCameraPreview(
            aspectRatio: 9 / 16,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );
    final aspect = tester.widget<AspectRatio>(
      find.byKey(const ValueKey('natural_camera_aspect_ratio')),
    );
    expect(aspect.aspectRatio, 9 / 16);
    expect(tester.getSize(find.byType(ClipRect)), const Size(450, 800));
  });
}
