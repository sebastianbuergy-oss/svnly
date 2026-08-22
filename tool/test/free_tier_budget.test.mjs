import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const migration = fs.readFileSync(
  new URL('../../supabase/migrations/202608220008_free_tier_budget.sql', import.meta.url),
  'utf8',
);
const scheduler = fs.readFileSync(
  new URL('../../supabase/functions/scheduled-jobs/index.ts', import.meta.url),
  'utf8',
);

test('free-tier storage reservations fail closed below the provider quota', () => {
  assert.match(migration, /v_budget_bytes constant bigint := 805306368/);
  assert.match(migration, /pg_advisory_xact_lock/);
  assert.match(migration, /free_tier_storage_budget_exceeded/);
  assert.match(migration, /p_file_size not between 1 and 12582912/);
});

test('media retention has a hard 21-day ceiling', () => {
  assert.match(scheduler, /freeTierRetentionDays = 21/);
  assert.match(scheduler, /Math\.min\(requestedDays \?\? freeTierRetentionDays/);
  assert.match(scheduler, /storage\.from\('takes'\)\.remove/);
});
