import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

const swift = await readFile(new URL('../../ios/Runner/AppDelegate.swift', import.meta.url), 'utf8');
const camera = await readFile(new URL('../../lib/features/camera/camera_screen.dart', import.meta.url), 'utf8');
const pending = await readFile(new URL('../../lib/features/camera/pending_upload_store.dart', import.meta.url), 'utf8');
const repository = await readFile(new URL('../../lib/features/auth/supabase_repository.dart', import.meta.url), 'utf8');

test('iPhone take export stays below the upload contract and queued takes are retried', () => {
  assert.match(swift, /AVAssetExportPreset1280x720/);
  assert.doesNotMatch(swift, /presetName:\s*AVAssetExportPresetHighestQuality/);
  assert.match(camera, /uploaded \? CaptureStage\.done : CaptureStage\.queued/);
  assert.match(pending, /if \(await file\.length\(\) > _maxUploadBytes\)/);
  assert.match(pending, /LiveLookProcessor\.burn/);
});

test('final MP4 produces three immutable moderation frames before finalize', () => {
  assert.match(swift, /frameTimes = \[0\.70, 3\.50, 6\.30\]/);
  assert.match(swift, /generator\.appliesPreferredTrackTransform = true/);
  assert.match(camera, /ModerationFrameExtractor\.extract\([\s\S]*processed\.file/);
  assert.match(pending, /ModerationFrameExtractor\.extract\(uploadFile\)/);
  assert.match(repository, /moderation-artifacts/);
  assert.match(repository, /frame-\$\{\(index \+ 1\)\.toString\(\)\.padLeft\(2, '0'\)\}\.jpg/);
  const videoUpload = repository.indexOf("bucket: 'takes'");
  const frameUpload = repository.indexOf("bucket: 'moderation-artifacts'");
  const finalizeCall = repository.indexOf("'finalize_take'");
  assert.ok(videoUpload >= 0 && videoUpload < frameUpload);
  assert.ok(frameUpload < finalizeCall);
  assert.match(repository, /upsert: false/);
});
