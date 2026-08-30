import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/features/camera/live_look_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ch.sebastianbuergy.svnly/video_processor');

  Uint8List jpeg(int fill) => Uint8List.fromList([
    0xff,
    0xd8,
    ...List<int>.filled(252, fill),
    0xff,
    0xd9,
  ]);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requests three frames from the final encoded video', () async {
    final frames = [jpeg(1), jpeg(2), jpeg(3)];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'extractModerationFrames');
          expect((call.arguments as Map)['inputPath'], 'final.mp4');
          return frames;
        });

    final result = await ModerationFrameExtractor.extract(File('final.mp4'));
    expect(result, frames);
  });

  test('rejects missing or malformed moderation frames', () {
    expect(
      () => ModerationFrameExtractor.validate([jpeg(1), jpeg(2)]),
      throwsStateError,
    );
    final malformed = Uint8List(256);
    expect(
      () => ModerationFrameExtractor.validate([jpeg(1), jpeg(2), malformed]),
      throwsStateError,
    );
  });
}
