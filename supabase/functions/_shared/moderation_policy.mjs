const rejectThresholds = Object.freeze({
  'sexual/minors': 0.2,
  'violence/graphic': 0.85,
  'hate/threatening': 0.85,
  'self-harm/instructions': 0.85,
  'illicit/violent': 0.9,
  sexual: 0.95,
});

const retryableExtractionErrors = new Set([
  'media_worker_unconfigured',
  'video_signing_failed',
  'trusted_extraction_failed',
  'video_download_failed',
  'moderation_frames_missing',
  'manifest_write_failed',
]);

export function isRetryableExtractionError(code) {
  return retryableExtractionErrors.has(code);
}

export function classifyModerationResults(results) {
  if (!Array.isArray(results) || results.length === 0) {
    throw new Error('invalid_moderation_response');
  }

  if (!results.some((entry) => entry?.flagged === true)) return 'publish';

  for (const entry of results) {
    const scores = entry?.category_scores;
    if (!scores || typeof scores !== 'object') continue;
    for (const [category, threshold] of Object.entries(rejectThresholds)) {
      const score = Number(scores[category]);
      if (Number.isFinite(score) && score >= threshold) return 'reject';
    }
  }
  return 'review';
}
