import assert from 'node:assert/strict';
import test from 'node:test';

import {authorized, validateProbe, validateSourceUrl} from '../server.mjs';

test('bearer comparison accepts only exact shared token', () => {
  assert.equal(authorized('Bearer trusted-secret', 'trusted-secret'), true);
  assert.equal(authorized('Bearer trusted-secreu', 'trusted-secret'), false);
  assert.equal(authorized(undefined, 'trusted-secret'), false);
});

test('video URL is pinned to the configured HTTPS storage host', () => {
  assert.equal(
    validateSourceUrl('https://project.supabase.co/storage/v1/object/sign/takes/a', 'project.supabase.co').hostname,
    'project.supabase.co',
  );
  assert.throws(() => validateSourceUrl('http://project.supabase.co/video', 'project.supabase.co'));
  assert.throws(() => validateSourceUrl('https://attacker.example/video', 'project.supabase.co'));
});

test('probe validation enforces duration, codec and dimensions', () => {
  assert.deepEqual(validateProbe({
    format: {duration: '7.02'},
    streams: [{codec_type: 'video', codec_name: 'h264', width: 1080, height: 1920}],
  }), {duration: 7.02, codec: 'h264', width: 1080, height: 1920});
  assert.throws(() => validateProbe({
    format: {duration: '10'},
    streams: [{codec_type: 'video', codec_name: 'h264', width: 1080, height: 1920}],
  }), /invalid_duration/);
  assert.throws(() => validateProbe({
    format: {duration: '7'},
    streams: [{codec_type: 'video', codec_name: 'vp9', width: 1080, height: 1920}],
  }), /invalid_video_codec/);
});
