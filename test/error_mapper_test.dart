import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:svnly/core/errors/error_mapper.dart';

void main() {
  test('maps authentication failures and preserves technical detail', () {
    expect(
      ErrorMapper.message(const AuthException('Invalid login credentials')),
      'Email or password is incorrect.',
    );
    expect(
      ErrorMapper.message(const AuthException('User already registered')),
      'This email is already registered.',
    );
    expect(
      ErrorMapper.message(
        const AuthException(
          'Apple token audience is invalid.',
          statusCode: '400',
          code: 'bad_jwt',
        ),
      ),
      'Authentication could not be completed.',
    );
    expect(
      ErrorMapper.technicalCode(
        const AuthException(
          'Apple token audience is invalid.',
          statusCode: '400',
          code: 'bad_jwt',
        ),
      ),
      'supabase.bad_jwt',
    );
  });

  test('maps connectivity and timeout failures', () {
    expect(
      ErrorMapper.message(const SocketException('offline')),
      'You appear to be offline.',
    );
    expect(
      ErrorMapper.message(TimeoutException('slow')),
      'The request took too long. Please try again.',
    );
  });

  test('uses a generic message for unknown errors', () {
    expect(
      ErrorMapper.message(StateError('sensitive detail')),
      'Something went wrong. Please try again.',
    );
  });
}
