import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

test('scheduled Edge job uses pg_net named-argument syntax supported in production', async () => {
  const migration = await readFile(
    new URL('../../supabase/migrations/202608300018_scheduler_pg_net_compatibility.sql', import.meta.url),
    'utf8',
  );
  assert.match(migration, /url\s*=>/);
  assert.match(migration, /body\s*=>/);
  assert.match(migration, /headers\s*=>/);
  assert.doesNotMatch(migration, /http_post\(url\s*=/);
});
