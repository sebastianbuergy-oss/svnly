import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/core/security/username_validator.dart';

void main() {
  group('UsernameValidator', () {
    test('accepts valid names', () {
      expect(UsernameValidator.validate('sebastian_7'), isNull);
      expect(UsernameValidator.validate('real.one'), isNull);
    });

    test('rejects invalid format', () {
      expect(UsernameValidator.validate('ab'), isNotNull);
      expect(UsernameValidator.validate('space name'), isNotNull);
      expect(UsernameValidator.validate('emoji🔥'), isNotNull);
    });

    test('rejects reserved and misleading names case-insensitively', () {
      expect(UsernameValidator.validate('SVNLY_team'), isNotNull);
      expect(UsernameValidator.validate('official.jane'), isNotNull);
      expect(UsernameValidator.validate('support7'), isNotNull);
    });
  });
}
