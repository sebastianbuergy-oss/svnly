import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';

const migration = await readFile(
  new URL('../../supabase/migrations/202608300021_owner_take_deletion.sql', import.meta.url),
  'utf8',
);
const edge = await readFile(
  new URL('../../supabase/functions/delete-take/index.ts', import.meta.url),
  'utf8',
);
const scheduler = await readFile(
  new URL('../../supabase/functions/scheduled-jobs/index.ts', import.meta.url),
  'utf8',
);

test('owner deletion is authorization-scoped and preserves participation', () => {
  assert.match(migration, /where t\.id=p_take_id and t\.user_id=auth\.uid\(\)/);
  assert.match(migration, /raise exception 'take_not_owned'/);
  assert.doesNotMatch(migration, /delete from public\.challenge_participations/);
  assert.match(migration, /status='deleted'/);
  assert.match(migration, /grant execute on function public\.delete_my_take\(uuid\) to authenticated/);
});

test('owner deletion removes social visibility while retaining cleanup paths', () => {
  for (const table of ['reactions', 'comments', 'take_views', 'notifications', 'moderation_queue']) {
    assert.match(migration, new RegExp(`delete from public\\.${table}`));
  }
  assert.match(migration, /where t\.user_id=auth\.uid\(\) and t\.status<>'deleted'/);
  assert.match(migration, /case when t\.status='deleted' then 'deleted'/);
  assert.match(migration, /storage_path=null/);
});

test('edge cleanup covers every private media object and cron retries failures', () => {
  for (const bucket of ['takes', 'take-thumbnails', 'moderation-artifacts']) {
    assert.match(edge, new RegExp(`'${bucket}'`));
  }
  for (const frame of ['frame-01.jpg', 'frame-02.jpg', 'frame-03.jpg']) {
    assert.match(edge, new RegExp(frame));
  }
  assert.match(edge, /complete_take_media_cleanup/);
  assert.match(edge, /cleanup: 'queued'/);
  assert.match(scheduler, /eq\('status', 'deleted'\)/);
  assert.match(scheduler, /complete_take_media_cleanup/);
});
