class UsernameValidator {
  static final _format = RegExp(r'^[a-zA-Z0-9._]{3,20}$');
  static const _reserved = {
    'admin',
    'administrator',
    'moderator',
    'support',
    'official',
    'svnly',
    'svnlyapp',
    'security',
    'help',
  };

  static String? validate(String value) {
    final normalized = value.trim().toLowerCase();
    if (!_format.hasMatch(value.trim())) {
      return 'Use 3–20 letters, numbers, dots or underscores.';
    }
    if (_reserved.any((word) => normalized.contains(word))) {
      return 'This username is reserved.';
    }
    return null;
  }
}
