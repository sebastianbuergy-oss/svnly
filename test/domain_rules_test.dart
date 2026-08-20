import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/core/domain/rules.dart';

void main() {
  test('challenge countdown is UTC-safe and never negative', () {
    expect(
      challengeRemaining(
        DateTime.parse('2026-08-21T00:00:00Z'),
        DateTime.parse('2026-08-20T23:59:50Z'),
      ),
      const Duration(seconds: 10),
    );
    expect(
      challengeRemaining(
        DateTime.parse('2026-08-20T00:00:00Z'),
        DateTime.parse('2026-08-21T00:00:00Z'),
      ),
      Duration.zero,
    );
  });

  test('streak calculation handles duplicates, gaps and yesterday', () {
    final result = calculateStreak([
      DateTime.utc(2026, 8, 15),
      DateTime.utc(2026, 8, 16),
      DateTime.utc(2026, 8, 18),
      DateTime.utc(2026, 8, 19),
      DateTime.utc(2026, 8, 19, 12),
    ], DateTime.utc(2026, 8, 20));
    expect(result.current, 2);
    expect(result.longest, 2);
  });

  test('ranking requires a sample and normalizes engagement', () {
    expect(
      normalizedRankingScore(
        impressions: 4,
        uniqueReactions: 4,
        uniqueCommenters: 4,
        completedViews: 4,
      ),
      0,
    );
    final score = normalizedRankingScore(
      impressions: 50,
      uniqueReactions: 10,
      uniqueCommenters: 5,
      completedViews: 40,
    );
    expect(score, closeTo(31.5, 0.01));
  });

  test('technical retry is limited and refuses finalized uploads', () {
    expect(
      technicalRetryAllowed(
        attemptStatus: 'started',
        hasFinalizedStoragePath: false,
        retryCount: 0,
      ),
      isTrue,
    );
    expect(
      technicalRetryAllowed(
        attemptStatus: 'started',
        hasFinalizedStoragePath: true,
        retryCount: 0,
      ),
      isFalse,
    );
    expect(
      technicalRetryAllowed(
        attemptStatus: 'technical_failure',
        hasFinalizedStoragePath: false,
        retryCount: 1,
      ),
      isFalse,
    );
  });

  test('permission decision distinguishes request from Settings recovery', () {
    expect(
      capturePermissionDecision(
        cameraGranted: true,
        microphoneGranted: true,
        permanentlyDenied: false,
      ),
      CapturePermissionDecision.ready,
    );
    expect(
      capturePermissionDecision(
        cameraGranted: false,
        microphoneGranted: true,
        permanentlyDenied: true,
      ),
      CapturePermissionDecision.openSettings,
    );
  });

  test('premium entitlement expires and block visibility is symmetric', () {
    final now = DateTime.utc(2026, 8, 20);
    expect(
      premiumEntitlementActive(
        entitlementPresent: true,
        expiresAt: now.add(const Duration(days: 1)),
        now: now,
      ),
      isTrue,
    );
    expect(
      premiumEntitlementActive(
        entitlementPresent: true,
        expiresAt: now.subtract(const Duration(seconds: 1)),
        now: now,
      ),
      isFalse,
    );
    expect(contentVisibleAcrossBlock(blockedEitherDirection: true), isFalse);
  });
}
