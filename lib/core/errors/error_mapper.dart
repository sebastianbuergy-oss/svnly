import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
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
