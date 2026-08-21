import 'dart:io';

import 'package:flutter/services.dart';

class ProcessedLiveLookVideo {
  const ProcessedLiveLookVideo({
    required this.file,
    required this.look,
    required this.byteCount,
  });

  final File file;
  final String look;
  final int byteCount;
}

abstract final class LiveLookProcessor {
  static const _channel = MethodChannel(
    'ch.sebastianbuergy.svnly/video_processor',
  );

  static Future<ProcessedLiveLookVideo> burn({
    required File source,
    required String attemptId,
    required String look,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError(
        'Live Look encoding requires the iOS native host.',
      );
    }
    final output = File('${source.parent.path}/svnly-$attemptId-filtered.mp4');
    final proof = await _channel.invokeMapMethod<String, dynamic>(
      'burnLiveLook',
      {'inputPath': source.path, 'outputPath': output.path, 'look': look},
    );
    final byteCount = (proof?['byteCount'] as num?)?.toInt() ?? 0;
    final filterApplied = proof?['filterApplied'] == true;
    final encodedLook = proof?['look'] as String?;
    if (!filterApplied || encodedLook != look || byteCount <= 0) {
      throw StateError('Native encoder did not prove the selected Live Look.');
    }
    final actualSize = await output.length();
    if (actualSize != byteCount || actualSize <= 0) {
      throw StateError('Processed video failed output integrity validation.');
    }
    return ProcessedLiveLookVideo(
      file: output,
      look: encodedLook!,
      byteCount: byteCount,
    );
  }
}
