import 'dart:typed_data';

import '../challenge/models.dart';

abstract interface class AppRepository {
  bool get hasSession;
  String? get userId;
  Stream<bool> get sessionChanges;

  Future<void> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<bool> hasCompletedProfile();
  Future<void> saveProfile({
    required String username,
    required String displayName,
    required String countryCode,
    required String languageCode,
    required String timezone,
    required DateTime dateOfBirth,
    required bool isPrivate,
  });
  Future<DailyChallenge> currentChallenge();
  Future<bool> hasTakeToday();
  Future<TakeAttempt> issueAttempt();
  Future<void> markAttemptStarted(String attemptId);
  Future<void> requestTechnicalRetry({
    required String attemptId,
    required String reason,
    required Map<String, Object?> diagnostics,
  });
  Future<void> finalizeTake({
    required TakeAttempt attempt,
    required Uint8List videoBytes,
    required int durationMs,
    required String look,
  });
  Future<List<FeedTake>> loadFeed(String scope, {int page = 0});
  Future<void> recordTakeView(String takeId, {required bool completed});
  Future<void> setReaction(String takeId, String? reaction);
  Future<void> createComment(String takeId, String body);
  Future<List<CommentItem>> loadComments(String takeId, {int page = 0});
  Future<void> deleteComment(String commentId);
  Future<void> follow(String profileId);
  Future<void> block(String profileId);
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  });
  Future<void> requestAccountDeletion();
  Future<List<Map<String, dynamic>>> loadRankings(String period, String scope);
  Future<Map<String, dynamic>> loadMyProfile();
  Future<List<MyTake>> loadMyTakes({int limit = 30});
  Future<void> updateProfile({
    required String username,
    required String displayName,
    required String bio,
    required String countryCode,
    String? avatarPath,
  });
  Future<String> uploadAvatar(Uint8List imageBytes);
  Future<void> updateSetting(String key, Object? value);
  Future<bool> registerForPush({required bool promptIfNeeded});
  Future<List<Map<String, dynamic>>> loadBlockedUsers();
  Future<void> unblock(String profileId);
  Future<void> createSupportTicket(String subject, String body);
}

class BackendNotConfigured implements Exception {
  const BackendNotConfigured();
  @override
  String toString() => 'SVNLY backend configuration is missing.';
}

class UnconfiguredRepository implements AppRepository {
  const UnconfiguredRepository();
  Never _missing() => throw const BackendNotConfigured();
  @override
  bool get hasSession => false;
  @override
  String? get userId => null;
  @override
  Stream<bool> get sessionChanges => const Stream.empty();
  @override
  Future<void> block(String profileId) async => _missing();
  @override
  Future<void> createComment(String takeId, String body) async => _missing();
  @override
  Future<List<CommentItem>> loadComments(String takeId, {int page = 0}) async =>
      _missing();
  @override
  Future<void> deleteComment(String commentId) async => _missing();
  @override
  Future<DailyChallenge> currentChallenge() async => _missing();
  @override
  Future<void> finalizeTake({
    required TakeAttempt attempt,
    required Uint8List videoBytes,
    required int durationMs,
    required String look,
  }) async => _missing();
  @override
  Future<void> follow(String profileId) async => _missing();
  @override
  Future<bool> hasCompletedProfile() async => false;
  @override
  Future<bool> hasTakeToday() async => false;
  @override
  Future<TakeAttempt> issueAttempt() async => _missing();
  @override
  Future<List<FeedTake>> loadFeed(String scope, {int page = 0}) async =>
      _missing();
  @override
  Future<void> recordTakeView(String takeId, {required bool completed}) async =>
      _missing();
  @override
  Future<void> markAttemptStarted(String attemptId) async => _missing();
  @override
  Future<void> requestTechnicalRetry({
    required String attemptId,
    required String reason,
    required Map<String, Object?> diagnostics,
  }) async => _missing();
  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async => _missing();
  @override
  Future<void> requestAccountDeletion() async => _missing();
  @override
  Future<List<Map<String, dynamic>>> loadRankings(
    String period,
    String scope,
  ) async => _missing();
  @override
  Future<Map<String, dynamic>> loadMyProfile() async => _missing();
  @override
  Future<List<MyTake>> loadMyTakes({int limit = 30}) async => _missing();
  @override
  Future<void> updateProfile({
    required String username,
    required String displayName,
    required String bio,
    required String countryCode,
    String? avatarPath,
  }) async => _missing();
  @override
  Future<String> uploadAvatar(Uint8List imageBytes) async => _missing();
  @override
  Future<void> updateSetting(String key, Object? value) async => _missing();
  @override
  Future<bool> registerForPush({required bool promptIfNeeded}) async =>
      _missing();
  @override
  Future<List<Map<String, dynamic>>> loadBlockedUsers() async => _missing();
  @override
  Future<void> unblock(String profileId) async => _missing();
  @override
  Future<void> createSupportTicket(String subject, String body) async =>
      _missing();
  @override
  Future<void> resetPassword(String email) async => _missing();
  @override
  Future<void> saveProfile({
    required String username,
    required String displayName,
    required String countryCode,
    required String languageCode,
    required String timezone,
    required DateTime dateOfBirth,
    required bool isPrivate,
  }) async => _missing();
  @override
  Future<void> setReaction(String takeId, String? reaction) async => _missing();
  @override
  Future<void> signIn(String email, String password) async => _missing();
  @override
  Future<void> signInWithApple() async => _missing();
  @override
  Future<void> signInWithGoogle() async => _missing();
  @override
  Future<void> signOut() async => _missing();
  @override
  Future<void> signUp(String email, String password) async => _missing();
}
