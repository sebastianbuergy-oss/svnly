import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

const double naturalCameraZoom = 1.0;

int naturalCameraIndex(
  List<CameraDescription> cameras,
  CameraLensDirection direction,
) {
  if (cameras.isEmpty) return -1;
  final matching = <int>[
    for (var index = 0; index < cameras.length; index++)
      if (cameras[index].lensDirection == direction) index,
  ];
  if (matching.isEmpty) return -1;

  for (final index in matching) {
    if (cameras[index].lensType == CameraLensType.wide) return index;
  }
  for (final index in matching) {
    if (cameras[index].lensType == CameraLensType.unknown) return index;
  }
  return matching.first;
}

Future<void> applyNaturalStartupZoom({
  required Future<double> Function() getMinZoom,
  required Future<double> Function() getMaxZoom,
  required Future<void> Function(double zoom) setZoom,
}) async {
  final minZoom = await getMinZoom();
  final maxZoom = await getMaxZoom();
  if (minZoom > naturalCameraZoom || maxZoom < naturalCameraZoom) {
    throw StateError(
      'The selected camera does not expose its native 1.0x field of view.',
    );
  }
  await setZoom(naturalCameraZoom);
}

class NaturalCameraPreview extends StatelessWidget {
  const NaturalCameraPreview({
    required this.aspectRatio,
    required this.child,
    super.key,
  });

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: AspectRatio(
        key: const ValueKey('natural_camera_aspect_ratio'),
        aspectRatio: aspectRatio,
        child: ClipRect(child: child),
      ),
    ),
  );
}
