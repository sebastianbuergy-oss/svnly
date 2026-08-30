import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../challenge/models.dart';
import '../notifications/push_registration.dart';
import 'app_repository.dart';

class SupabaseAppRepository implements AppRepository {
  SupabaseAppRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get hasSession => _client.auth.currentSession != null;
  @override
  String? get userId => _client.auth.currentUser?.id;
  @override
  Stream<bool> get sessionChanges => _client.auth.onAuthStateChange
      .map((event) => event.session != null)
      .distinct();

  @override
  Future<void> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: 'svnly://auth/callback',
    );
    if (response.user == null) {
      throw const AuthException(
        'Supabase did not return a user after sign-up.',
        code: 'signup_user_missing',
      );
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithApple() async {
    final rawNonce = _client.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AuthException(
        'Apple did not return an identity token.',
        code: 'apple_identity_token_missing',
      );
    }
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: identityToken,
      nonce: rawNonce,
    );
    if (response.user == null || response.session == null) {
      throw const AuthException(
        'Supabase did not create an Apple session.',
        code: 'apple_session_missing',
      );
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'svnly://auth/callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const AuthException(
        'The Google authorization page could not be opened.',
        code: 'google_oauth_launch_failed',
      );
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'svnly://auth/reset-password',
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.global);

  @override
  Future<bool> hasCompletedProfile() async {
    final id = userId;
    if (id == null) return false;
    final value = await _client
        .from('profiles')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    return value != null;
  }

  @override
  Future<void> saveProfile({
    required String username,
    required String displayName,
    required String countryCode,
    required String languageCode,
    required String timezone,
    required DateTime dateOfBirth,
    required bool isPrivate,
  }) async {
    await _client.rpc(
      'complete_profile',
      params: {
        'p_username': username.trim(),
        'p_display_name': displayName.trim(),
        'p_country_code': countryCode,
        'p_language_code': languageCode,
        'p_timezone': timezone,
        'p_date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'p_is_private': isPrivate,
        'p_terms_version': '1.0',
        'p_privacy_version': '1.0',
        'p_guidelines_version': '1.0',
      },
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<DailyChallenge> currentChallenge() async =>
      DailyChallenge.fromJson(_map(await _client.rpc('current_challenge')));

  @override
  Future<bool> hasTakeToday() async =>
      (await _client.rpc('has_valid_take_today')) as bool? ?? false;

  @override
  Future<TakeAttempt> issueAttempt() async =>
      TakeAttempt.fromJson(_map(await _client.rpc('issue_take_attempt')));

  @override
  Future<void> markAttemptStarted(String attemptId) async {
    await _client.rpc(
      'mark_attempt_started',
      params: {'p_attempt_id': attemptId},
    );
  }

  @override
  Future<void> requestTechnicalRetry({
    required String attemptId,
    required String reason,
    required Map<String, Object?> diagnostics,
  }) async {
    await _client.rpc(
      'request_technical_retry',
      params: {
        'p_attempt_id': attemptId,
        'p_reason': reason,
        'p_diagnostics': diagnostics,
      },
    );
  }

  @override
  Future<void> finalizeTake({
    required TakeAttempt attempt,
    required Uint8List videoBytes,
    required int durationMs,
    required String look,
  }) async {
    if (videoBytes.isEmpty || videoBytes.lengthInBytes > 12 * 1024 * 1024) {
      throw StateError(
        'Recorded video is missing or exceeds the upload limit.',
      );
    }
    final takeId = await _client.rpc(
      'reserve_take_upload',
      params: {
        'p_attempt_id': attempt.id,
        'p_nonce': attempt.nonce,
        'p_duration_ms': durationMs,
        'p_file_size': videoBytes.lengthInBytes,
        'p_look': look,
      },
    ) as String;
    final path = '${userId!}/${attempt.id}/$takeId/video.mp4';
    await _client.storage
        .from('takes')
        .uploadBinary(
          path,
          videoBytes,
          fileOptions: const FileOptions(
            contentType: 'video/mp4',
            cacheControl: '0',
            upsert: false,
          ),
        );
    await _client.rpc(
      'finalize_take',
      params: {
        'p_take_id': takeId,
        'p_attempt_id': attempt.id,
        'p_storage_path': path,
        'p_duration_ms': durationMs,
        'p_file_size': videoBytes.lengthInBytes,
      },
    );
    try {
      await _client.functions.invoke('moderate-take', body: {'takeId': takeId});
    } catch (_) {
      // A scheduled server worker retries unresolved moderation queue items.
    }
  }

  @override
  Future<List<FeedTake>> loadFeed(String scope, {int page = 0}) async {
    final response = await _client.rpc(
      'get_daily_feed',
      params: {'p_scope': scope, 'p_limit': 10, 'p_offset': page * 10},
    ) as List<dynamic>;
    return Future.wait(
      response.map((item) async {
        final json = Map<String, dynamic>.from(item as Map);
        final path = json.remove('storage_path') as String;
        json['video_url'] = await _client.storage
            .from('takes')
            .createSignedUrl(path, 90);
        return FeedTake.fromJson(json);
      }),
    );
  }

  @override
  Future<void> setReaction(String takeId, String? reaction) async {
    await _client.rpc(
      'set_reaction',
      params: {'p_take_id': takeId, 'p_reaction': reaction},
    );
  }

  @override
  Future<void> recordTakeView(String takeId, {required bool completed}) async {
    await _client.rpc(
      'record_take_view',
      params: {'p_take_id': takeId, 'p_completed': completed},
    );
  }

  @override
  Future<void> createComment(String takeId, String body) async {
    await _client.rpc(
      'create_comment',
      params: {'p_take_id': takeId, 'p_body': body.trim()},
    );
  }

  @override
  Future<List<CommentItem>> loadComments(String takeId, {int page = 0}) async {
    final response = await _client.rpc(
      'get_comments',
      params: {'p_take_id': takeId, 'p_limit': 30, 'p_offset': page * 30},
    ) as List<dynamic>;
    return response
        .map(
          (item) =>
              CommentItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.rpc('delete_comment', params: {'p_comment_id': commentId});
  }

  @override
  Future<void> follow(String profileId) async {
    await _client.rpc('follow_profile', params: {'p_profile_id': profileId});
  }

  @override
  Future<void> block(String profileId) async {
    await _client.rpc('block_profile', params: {'p_profile_id': profileId});
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    await _client.rpc(
      'create_report',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reason': reason,
        'p_details': details,
      },
    );
  }

  @override
  Future<void> requestAccountDeletion() async {
    final response = await _client.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Account deletion request failed.');
    }
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  @override
  Future<List<Map<String, dynamic>>> loadRankings(
    String period,
    String scope,
  ) async {
    final response = await _client.rpc(
      'get_rankings',
      params: {'p_period': period, 'p_scope': scope, 'p_limit': 100},
    ) as List<dynamic>;
    return response
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> loadMyProfile() async {
    final profile = _map(await _client.rpc('get_my_profile'));
    final path = profile['avatar_path'] as String?;
    if (path != null && path.isNotEmpty) {
      profile['avatar_url'] = await _client.storage
          .from('avatars')
          .createSignedUrl(path, 600);
    }
    return profile;
  }

  @override
  Future<List<MyTake>> loadMyTakes({int limit = 30}) async {
    final response = await _client.rpc(
      'get_my_takes',
      params: {'p_limit': limit},
    ) as List<dynamic>;
    return Future.wait(
      response.map((raw) async {
        final json = Map<String, dynamic>.from(raw as Map);
        final videoPath = json.remove('storage_path') as String?;
        final thumbnailPath = json.remove('thumbnail_path') as String?;
        if (videoPath != null && videoPath.isNotEmpty) {
          json['video_url'] = await _client.storage
              .from('takes')
              .createSignedUrl(videoPath, 600);
        }
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          json['thumbnail_url'] = await _client.storage
              .from('take-thumbnails')
              .createSignedUrl(thumbnailPath, 600);
        }
        return MyTake.fromJson(json);
      }),
    );
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes) async {
    if (imageBytes.isEmpty || imageBytes.lengthInBytes > 5 * 1024 * 1024) {
      throw StateError('Avatar is missing or exceeds the upload limit.');
    }
    final id = userId;
    if (id == null) throw const AuthException('Authentication required.');
    final path = '$id/avatar.jpg';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '3600',
            upsert: true,
          ),
        );
    return path;
  }

  @override
  Future<void> updateProfile({
    required String username,
    required String displayName,
    required String bio,
    required String countryCode,
    String? avatarPath,
  }) async {
    await _client.rpc(
      'update_my_profile',
      params: {
        'p_username': username.trim(),
        'p_display_name': displayName.trim(),
        'p_bio': bio.trim(),
        'p_country_code': countryCode,
        'p_avatar_path': avatarPath,
      },
    );
  }

  @override
  Future<void> updateSetting(String key, Object? value) async {
    const allowed = {
      'language_code',
      'is_private',
      'comment_permission',
      'daily_challenge_push',
      'streak_push',
      'reaction_push',
      'comment_push',
      'follower_push',
      'moderation_push',
      'product_news_push',
      'auto_delete_days',
    };
    if (!allowed.contains(key)) throw ArgumentError.value(key, 'key');
    await _client.rpc(
      'update_user_setting',
      params: {'p_key': key, 'p_value': value},
    );
  }

  @override
  Future<bool> registerForPush({required bool promptIfNeeded}) async {
    final registration = await PushRegistrationService.register(
      promptIfNeeded: promptIfNeeded,
    );
    if (registration == null) return false;
    final response = await _client.functions.invoke(
      'register-device',
      body: {
        'token': registration.token,
        'environment': registration.environment,
        'locale': registration.locale,
        'timezone': registration.timezone,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('APNs device registration was rejected.');
    }
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> loadBlockedUsers() async {
    final response = await _client.rpc('get_blocked_users') as List<dynamic>;
    return response
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  @override
  Future<void> unblock(String profileId) async {
    await _client.rpc('unblock_profile', params: {'p_profile_id': profileId});
  }

  @override
  Future<void> createSupportTicket(String subject, String body) async {
    await _client.rpc(
      'create_support_ticket',
      params: {'p_subject': subject.trim(), 'p_body': body.trim()},
    );
  }
}
