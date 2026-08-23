import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  static String authMessage(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    final code = technicalCode(error);
    developer.log(
      'operation=$operation code=$code error=$error',
      name: 'svnly.auth',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    return '${message(error)}\nCode: $code';
  }

  static String technicalCode(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      return 'apple.${error.code.name}';
    }
    if (error is SignInWithAppleNotSupportedException) {
      return 'apple.notSupported';
    }
    if (error is SignInWithAppleCredentialsException) {
      return 'apple.credentials';
    }
    if (error is AuthException) {
      final code = error.code;
      if (code != null && code.isNotEmpty) return 'supabase.$code';
      final statusCode = error.statusCode;
      if (statusCode != null && statusCode.isNotEmpty) {
        return 'supabase.http_$statusCode';
      }
      return 'supabase.unknown';
    }
    if (error is SocketException) return 'network.offline';
    if (error is TimeoutException) return 'network.timeout';
    return 'client.${error.runtimeType}';
  }

  static String message(Object error) {
    if (error is AuthException) {
      final value = error.message.toLowerCase();
      if (value.contains('invalid login')) {
        return 'Email or password is incorrect.';
      }
      if (value.contains('already registered')) {
        return 'This email is already registered.';
      }
      if (value.contains('rate')) {
        return 'Too many attempts. Please wait and try again.';
      }
      if (value.contains('email not confirmed')) {
        return 'Please verify your email first.';
      }
      return 'Authentication could not be completed.';
    }
    if (error is SocketException) return 'You appear to be offline.';
    if (error is TimeoutException) {
      return 'The request took too long. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
