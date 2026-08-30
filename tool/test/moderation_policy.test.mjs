import assert from 'node:assert/strict';
import test from 'node:test';

import {
  classifyModerationResults,
  isRetryableExtractionError,
} from '../../supabase/functions/_shared/moderation_policy.mjs';

test('harmless automated moderation publishes immediately', () => {
  assert.equal(classifyModerationResults([{flagged: false, category_scores: {sexual: 0.001}}]), 'publish');
});

test('borderline flagged content is routed to human review', () => {
  assert.equal(classifyModerationResults([{
    flagged: true,
    category_scores: {sexual: 0.35, 'violence/graphic': 0.1},
  }]), 'review');
});

test('clear high-confidence violations are rejected', () => {
  assert.equal(classifyModerationResults([{
    flagged: true,
    category_scores: {'violence/graphic': 0.97},
  }]), 'reject');
});

test('malformed provider responses cannot publish content', () => {
  assert.throws(() => classifyModerationResults([]), /invalid_moderation_response/);
});

test('infrastructure extraction failures are retried, not mislabeled as content edge cases', () => {
  assert.equal(isRetryableExtractionError('media_worker_unconfigured'), true);
  assert.equal(isRetryableExtractionError('video_signing_failed'), true);
  assert.equal(isRetryableExtractionError('invalid_duration'), false);
});
