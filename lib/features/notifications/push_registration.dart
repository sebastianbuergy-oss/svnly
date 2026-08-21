import 'dart:io';

import 'package:flutter/services.dart';

class PushRegistration {
  const PushRegistration({
    required this.token,
    required this.environment,
    required this.locale,
    required this.timezone,
  });

  final String token;
  final String environment;
  final String locale;
  final String timezone;
}

abstract final class PushRegistrationService {
  static const _channel = MethodChannel('ch.sebastianbuergy.svnly/push');

  static Future<PushRegistration?> register({
    required bool promptIfNeeded,
  }) async {
    if (!Platform.isIOS) return null;
    final response = await _channel.invokeMapMethod<String, dynamic>(
      promptIfNeeded ? 'requestRegistration' : 'refreshRegistration',
    );
    if (response?['granted'] != true) return null;
    final token = response?['token'] as String? ?? '';
    final environment = response?['environment'] as String? ?? '';
    if (token.isEmpty ||
        !const {'sandbox', 'production'}.contains(environment)) {
      throw StateError('APNs returned an invalid registration.');
    }
    return PushRegistration(
      token: token,
      environment: environment,
      locale: response?['locale'] as String? ?? 'en',
      timezone: response?['timezone'] as String? ?? 'UTC',
    );
  }
}
