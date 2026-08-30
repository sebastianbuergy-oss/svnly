import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/features/challenge/models.dart';

void main() {
  test('DailyChallenge parses UTC expiry and bilingual copy', () {
    final challenge = DailyChallenge.fromJson({
      'id': 'challenge-1',
      'challenge_date': '2026-08-20',
      'title_en': 'Freeze frame',
      'title_de': 'Standbild',
      'description_en': 'Do not move.',
      'description_de': 'Nicht bewegen.',
      'category': 'movement',
      'expires_at': '2026-08-21T02:00:00+02:00',
      'participant_count': 42.0,
    });

    expect(challenge.expiresAt, DateTime.utc(2026, 8, 21));
    expect(challenge.title('de'), 'Standbild');
    expect(challenge.title('fr'), 'Freeze frame');
    expect(challenge.description('de'), 'Nicht bewegen.');
    expect(challenge.participantCount, 42);
  });

  test('TakeAttempt applies retry defaults and normalizes UTC', () {
    final attempt = TakeAttempt.fromJson({
      'attempt_id': 'attempt-1',
      'nonce': 'trusted-nonce',
      'expires_at': '2026-08-20T19:00:00+02:00',
    });

    expect(attempt.retryCount, 0);
    expect(attempt.expiresAt, DateTime.utc(2026, 8, 20, 17));
  });

  test('FeedTake and CommentItem use safe count and ownership defaults', () {
    final take = FeedTake.fromJson({
      'id': 'take-1',
      'profile_id': 'profile-1',
      'username': 'seven',
      'display_name': 'Seven',
      'country_code': 'CH',
      'video_url': 'https://example.test/take.mp4',
      'challenge_title': 'Freeze frame',
    });
    final comment = CommentItem.fromJson({
      'id': 'comment-1',
      'profile_id': 'profile-2',
      'username': 'real-human',
      'body': 'Nice take',
      'created_at': '2026-08-20T17:00:00Z',
    });

    expect(take.reactionCount, 0);
    expect(take.commentCount, 0);
    expect(take.myReaction, isNull);
    expect(comment.isMine, isFalse);
  });

  test('MyTake keeps owner-visible moderation and participation state', () {
    final take = MyTake.fromJson({
      'id': 'take-7',
      'challenge_id': 'challenge-7',
      'challenge_title': 'Show the chaos',
      'challenge_date': '2026-08-30',
      'video_url': 'https://example.test/take.mp4',
      'take_status': 'under_review',
      'participation_status': 'completed',
      'reaction_count': 4,
      'comment_count': 2,
      'view_count': 19,
      'created_at': '2026-08-30T10:00:00Z',
      'is_today': true,
    });

    expect(take.isPlayable, isTrue);
    expect(take.displayStatus, 'UNDER REVIEW');
    expect(take.viewCount, 19);
    expect(take.isToday, isTrue);
  });

  test('deleted My Take keeps participation but exposes no playable media', () {
    final take = MyTake.fromJson({
      'id': null,
      'challenge_id': 'challenge-7',
      'challenge_title': 'Show the chaos',
      'challenge_date': '2026-08-30',
      'take_status': 'deleted',
      'participation_status': 'completed',
      'created_at': '2026-08-30T10:00:00Z',
      'is_today': true,
    });

    expect(take.isDeleted, isTrue);
    expect(take.isPlayable, isFalse);
    expect(take.displayStatus, 'DELETED');
    expect(take.participationStatus, 'completed');
  });
}
