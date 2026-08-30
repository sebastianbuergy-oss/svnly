import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

const edge = await readFile(
  new URL('../../supabase/functions/moderate-take/index.ts', import.meta.url),
  'utf8',
);
const migration = await readFile(
  new URL('../../supabase/migrations/202608300019_client_moderation_frames.sql', import.meta.url),
  'utf8',
);

test('V1 moderation falls back to immutable private frames without a media worker', () => {
  assert.match(edge, /if \(!mediaWorkerUrl \|\| !mediaWorkerToken\) return loadImmutableClientFrames\(take\)/);
  assert.match(edge, /frame-01\.jpg', 'frame-02\.jpg', 'frame-03\.jpg/);
  assert.match(edge, /https:\/\/api\.openai\.com\/v1\/moderations/);
  assert.match(edge, /model: 'omni-moderation-latest'/);
  assert.match(edge, /trustModel: 'immutable_owner_upload_from_signed_ios_capture'/);
});

test('moderation artifacts are insert-only and scoped to the reserved owner take', () => {
  assert.match(migration, /on storage\.objects for insert to authenticated/);
  assert.match(migration, /frame-0\[1-3\]\\\.jpg/);
  assert.match(migration, /t\.user_id=auth\.uid\(\)/);
  assert.match(migration, /t\.status='processing'/);
  assert.match(migration, /t\.storage_path is null/);
  assert.doesNotMatch(migration, /for update to authenticated/);
});
