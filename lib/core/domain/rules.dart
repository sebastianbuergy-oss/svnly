import 'dart:math' as math;

Duration challengeRemaining(DateTime expiresAt, DateTime now) {
  final value = expiresAt.toUtc().difference(now.toUtc());
  return value.isNegative ? Duration.zero : value;
}

({int current, int longest}) calculateStreak(
  Iterable<DateTime> completions,
  DateTime todayUtc,
) {
  final dates =
      completions
          .map((date) => DateTime.utc(date.year, date.month, date.day))
          .toSet()
          .toList()
        ..sort();
  if (dates.isEmpty) return (current: 0, longest: 0);

  var longest = 1;
  var run = 1;
  for (var index = 1; index < dates.length; index++) {
    if (dates[index].difference(dates[index - 1]).inDays == 1) {
      run++;
      longest = math.max(longest, run);
    } else {
      run = 1;
    }
  }
  final today = DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day);
  final last = dates.last;
  final current = today.difference(last).inDays <= 1 ? run : 0;
  return (current: current, longest: longest);
}

double normalizedRankingScore({
  required int impressions,
  required int uniqueReactions,
  required int uniqueCommenters,
  required int completedViews,
}) {
  if (impressions < 5) return 0;
  final reactionRate = math.min(uniqueReactions / impressions, 1);
  final commentRate = math.min(uniqueCommenters / impressions, 1);
  final completionRate = math.min(completedViews / impressions, 1);
  final confidence = math.min(1, math.log(1 + impressions) / math.log(51));
  return ((40 * reactionRate + 35 * commentRate + 25 * completionRate) *
          confidence)
      .toDouble();
}

bool technicalRetryAllowed({
  required String attemptStatus,
  required bool hasFinalizedStoragePath,
  required int retryCount,
}) =>
    const {'issued', 'started', 'upload_reserved'}.contains(attemptStatus) &&
    !hasFinalizedStoragePath &&
    retryCount < 1;

enum CapturePermissionDecision { ready, request, openSettings }

CapturePermissionDecision capturePermissionDecision({
  required bool cameraGranted,
  required bool microphoneGranted,
  required bool permanentlyDenied,
}) {
  if (cameraGranted && microphoneGranted) {
    return CapturePermissionDecision.ready;
  }
  return permanentlyDenied
      ? CapturePermissionDecision.openSettings
      : CapturePermissionDecision.request;
}

bool premiumEntitlementActive({
  required bool entitlementPresent,
  DateTime? expiresAt,
  required DateTime now,
}) =>
    entitlementPresent &&
    (expiresAt == null || expiresAt.toUtc().isAfter(now.toUtc()));

bool contentVisibleAcrossBlock({required bool blockedEitherDirection}) =>
    !blockedEitherDirection;
