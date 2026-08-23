class BuildIdentity {
  const BuildIdentity._();

  static const commitSha = String.fromEnvironment(
    'GIT_COMMIT_SHA',
    defaultValue: 'development',
  );
  static const buildNumber = String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 'local',
  );

  static String get shortCommit =>
      commitSha.length > 8 ? commitSha.substring(0, 8) : commitSha;

  static String get label => 'Build $buildNumber · $shortCommit';
}
