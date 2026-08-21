import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_repository.dart';
import '../challenge/models.dart';

class PendingUploadStore {
  static const _metadataKey = 'pending_take_upload';

  static Future<void> persist({
    required File source,
    required TakeAttempt attempt,
    required int durationMs,
    required String look,
  }) async {
    final directory = await getApplicationSupportDirectory();
    final target = File('${directory.path}/pending-${attempt.id}.mp4');
    await source.copy(target.path);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _metadataKey,
      jsonEncode({
        'path': target.path,
        'attempt_id': attempt.id,
        'nonce': attempt.nonce,
        'expires_at': attempt.expiresAt.toIso8601String(),
        'retry_count': attempt.retryCount,
        'duration_ms': durationMs,
        'look': look,
      }),
    );
  }

  static Future<bool> resume(AppRepository repository) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_metadataKey);
    if (encoded == null) return false;
    final value = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    final file = File(value['path'] as String);
    if (!await file.exists()) {
      await preferences.remove(_metadataKey);
      return false;
    }
    final attempt = TakeAttempt(
      id: value['attempt_id'] as String,
      nonce: value['nonce'] as String,
      expiresAt: DateTime.parse(value['expires_at'] as String),
      retryCount: value['retry_count'] as int,
    );
    await repository.finalizeTake(
      attempt: attempt,
      videoBytes: await file.readAsBytes(),
      durationMs: value['duration_ms'] as int,
      look: value['look'] as String,
    );
    await file.delete();
    await preferences.remove(_metadataKey);
    return true;
  }
}
