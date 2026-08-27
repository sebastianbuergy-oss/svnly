import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

const swift = await readFile(new URL('../../ios/Runner/AppDelegate.swift', import.meta.url), 'utf8');
const camera = await readFile(new URL('../../lib/features/camera/camera_screen.dart', import.meta.url), 'utf8');
const pending = await readFile(new URL('../../lib/features/camera/pending_upload_store.dart', import.meta.url), 'utf8');

test('iPhone take export stays below the upload contract and queued takes are retried', () => {
  assert.match(swift, /AVAssetExportPreset1280x720/);
  assert.doesNotMatch(swift, /presetName:\s*AVAssetExportPresetHighestQuality/);
  assert.match(camera, /uploaded \? CaptureStage\.done : CaptureStage\.queued/);
  assert.match(pending, /if \(await file\.length\(\) > _maxUploadBytes\)/);
  assert.match(pending, /LiveLookProcessor\.burn/);
});
