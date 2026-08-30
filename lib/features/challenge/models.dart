class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.challengeDate,
    required this.titleEn,
    required this.titleDe,
    required this.descriptionEn,
    required this.descriptionDe,
    required this.category,
    required this.expiresAt,
    this.participantCount = 0,
  });

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
    id: json['id'] as String,
    challengeDate: DateTime.parse(json['challenge_date'] as String),
    titleEn: json['title_en'] as String,
    titleDe: json['title_de'] as String,
    descriptionEn: json['description_en'] as String? ?? '',
    descriptionDe: json['description_de'] as String? ?? '',
    category: json['category'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
    participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final DateTime challengeDate;
  final String titleEn;
  final String titleDe;
  final String descriptionEn;
  final String descriptionDe;
  final String category;
  final DateTime expiresAt;
  final int participantCount;

  String title(String languageCode) => languageCode == 'de' ? titleDe : titleEn;
  String description(String languageCode) =>
      languageCode == 'de' ? descriptionDe : descriptionEn;
}

class TakeAttempt {
  const TakeAttempt({
    required this.id,
    required this.nonce,
    required this.expiresAt,
    required this.retryCount,
  });

  factory TakeAttempt.fromJson(Map<String, dynamic> json) => TakeAttempt(
    id: json['attempt_id'] as String,
    nonce: json['nonce'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
    retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String nonce;
  final DateTime expiresAt;
  final int retryCount;
}

class FeedTake {
  const FeedTake({
    required this.id,
    required this.profileId,
    required this.username,
    required this.displayName,
    required this.countryCode,
    required this.videoUrl,
    required this.challengeTitle,
    required this.reactionCount,
    required this.commentCount,
    this.myReaction,
  });

  factory FeedTake.fromJson(Map<String, dynamic> json) => FeedTake(
    id: json['id'] as String,
    profileId: json['profile_id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    countryCode: json['country_code'] as String,
    videoUrl: json['video_url'] as String,
    challengeTitle: json['challenge_title'] as String,
    reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
    commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    myReaction: json['my_reaction'] as String?,
  );

  final String id;
  final String profileId;
  final String username;
  final String displayName;
  final String countryCode;
  final String videoUrl;
  final String challengeTitle;
  final int reactionCount;
  final int commentCount;
  final String? myReaction;
}

class MyTake {
  const MyTake({
    required this.challengeId,
    required this.challengeTitle,
    required this.challengeDate,
    required this.status,
    required this.participationStatus,
    required this.reactionCount,
    required this.commentCount,
    required this.viewCount,
    required this.createdAt,
    required this.isToday,
    this.id,
    this.videoUrl,
    this.thumbnailUrl,
  });

  factory MyTake.fromJson(Map<String, dynamic> json) => MyTake(
    id: json['id'] as String?,
    challengeId: json['challenge_id'] as String,
    challengeTitle: json['challenge_title'] as String,
    challengeDate: DateTime.parse(json['challenge_date'] as String),
    videoUrl: json['video_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    status: json['take_status'] as String? ?? 'uploading',
    participationStatus: json['participation_status'] as String? ?? 'uploading',
    reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
    commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
    isToday: json['is_today'] as bool? ?? false,
  );

  final String? id;
  final String challengeId;
  final String challengeTitle;
  final DateTime challengeDate;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String status;
  final String participationStatus;
  final int reactionCount;
  final int commentCount;
  final int viewCount;
  final DateTime createdAt;
  final bool isToday;

  bool get isPlayable => videoUrl?.isNotEmpty == true;
  bool get isDeleted => status == 'deleted';
  String get displayStatus => switch (status) {
    'published' => 'LIVE',
    'under_review' => 'UNDER REVIEW',
    'processing' => 'PROCESSING',
    'rejected' => 'REVIEWED',
    'deleted' => 'DELETED',
    _ =>
      participationStatus == 'completed'
          ? 'PROCESSING'
          : participationStatus.toUpperCase().replaceAll('_', ' '),
  };
}

class CommentItem {
  const CommentItem({
    required this.id,
    required this.profileId,
    required this.username,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });
  factory CommentItem.fromJson(Map<String, dynamic> json) => CommentItem(
    id: json['id'] as String,
    profileId: json['profile_id'] as String,
    username: json['username'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    isMine: json['is_mine'] as bool? ?? false,
  );
  final String id;
  final String profileId;
  final String username;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}
