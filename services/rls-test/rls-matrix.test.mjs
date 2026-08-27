import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';
import {dirname, join} from 'node:path';
import {PGlite} from '@electric-sql/pglite';
import {citext} from '@electric-sql/pglite/contrib/citext';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const db = new PGlite({extensions: {citext, pgcrypto}});
const ids = {
  alice: '00000000-0000-4000-8000-000000000001',
  bob: '00000000-0000-4000-8000-000000000002',
  privateUser: '00000000-0000-4000-8000-000000000003',
  admin: '00000000-0000-4000-8000-000000000004',
  challenge: '10000000-0000-4000-8000-000000000001',
  tomorrow: '10000000-0000-4000-8000-000000000002',
  aliceTake: '20000000-0000-4000-8000-000000000001',
  bobTake: '20000000-0000-4000-8000-000000000002',
  privateTake: '20000000-0000-4000-8000-000000000003',
  pendingTake: '20000000-0000-4000-8000-000000000004',
};

async function owner(sql, params = []) {
  await db.exec('reset role');
  if (params.length || /^\s*select\b/i.test(sql)) return db.query(sql, params);
  return db.exec(sql);
}

async function asUser(userId, sql, params = [], role = 'user') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false), set_config('request.jwt.claims',$2,false)", [
    userId,
    JSON.stringify({sub: userId, app_metadata: {role}}),
  ]);
  await db.exec('set role authenticated');
  try {
    return params.length ? await db.query(sql, params) : await db.query(sql);
  } finally {
    await db.exec('reset role');
  }
}

async function countAs(userId, table, where = 'true', role = 'user') {
  const result = await asUser(userId, `select count(*)::integer count from ${table} where ${where}`, [], role);
  return result.rows[0].count;
}

async function applyMigrations() {
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create role service_role nologin bypassrls;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}'::jsonb);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
    $$;
    create function auth.jwt() returns jsonb language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
    $$;
    create table storage.buckets(
      id text primary key,name text not null,public boolean not null default false,
      file_size_limit bigint,allowed_mime_types text[]
    );
    create table storage.objects(
      id uuid primary key default gen_random_uuid(),bucket_id text not null references storage.buckets(id),
      name text not null,owner_id uuid
    );
    alter table storage.objects enable row level security;
    grant usage on schema public,auth,storage to authenticated,anon,service_role;
    grant select,insert,update,delete on storage.objects to authenticated;
  `);
  for (const name of [
    '202608200001_initial_schema.sql',
    '202608200002_secure_functions.sql',
    '202608200003_rls_storage.sql',
    '202608200004_admin_social_jobs.sql',
    '202608200005_rankings_streaks_views.sql',
    '202608210006_notification_outbox.sql',
    '202608270010_finalize_unlock_and_retry.sql',
  ]) {
    await db.exec(await readFile(join(root, 'supabase', 'migrations', name), 'utf8'));
  }
}

async function seedMatrix() {
  await owner(`
    insert into auth.users(id) values
      ('${ids.alice}'),('${ids.bob}'),('${ids.privateUser}'),('${ids.admin}');
    insert into public.profiles(id,username,display_name,country_code,is_private) values
      ('${ids.alice}','alice.real','Alice','CH',false),
      ('${ids.bob}','bob.real','Bob','DE',false),
      ('${ids.privateUser}','quiet.person','Private Person','CH',true),
      ('${ids.admin}','staff.member','Staff','CH',false);
    insert into public.challenges(id,challenge_date,title_en,title_de,description_en,description_de,
      category,status,publish_at,expires_at) values
      ('${ids.challenge}',current_date,'Show today','Zeig heute','','','everyday','active',
        current_date::timestamptz,current_date::timestamptz+interval '1 day'),
      ('${ids.tomorrow}',current_date+1,'Show tomorrow','Zeig morgen','','','everyday','scheduled',
        (current_date+1)::timestamptz,(current_date+2)::timestamptz);
    insert into public.take_attempts(id,user_id,challenge_id,nonce,status,finalized_at) values
      ('30000000-0000-4000-8000-000000000001','${ids.alice}','${ids.challenge}',gen_random_uuid(),'finalized',now()),
      ('30000000-0000-4000-8000-000000000002','${ids.bob}','${ids.challenge}',gen_random_uuid(),'finalized',now()),
      ('30000000-0000-4000-8000-000000000003','${ids.privateUser}','${ids.challenge}',gen_random_uuid(),'finalized',now()),
      ('30000000-0000-4000-8000-000000000004','${ids.alice}','${ids.tomorrow}',gen_random_uuid(),'upload_reserved',null);
    insert into public.takes(id,user_id,challenge_id,attempt_id,storage_path,duration_ms,file_size,status,published_at) values
      ('${ids.aliceTake}','${ids.alice}','${ids.challenge}','30000000-0000-4000-8000-000000000001','${ids.alice}/${ids.challenge}/${ids.aliceTake}.mp4',7000,1000,'published',now()),
      ('${ids.bobTake}','${ids.bob}','${ids.challenge}','30000000-0000-4000-8000-000000000002','${ids.bob}/${ids.challenge}/${ids.bobTake}.mp4',7000,1000,'published',now()),
      ('${ids.privateTake}','${ids.privateUser}','${ids.challenge}','30000000-0000-4000-8000-000000000003','${ids.privateUser}/${ids.challenge}/${ids.privateTake}.mp4',7000,1000,'published',now()),
      ('${ids.pendingTake}','${ids.alice}','${ids.tomorrow}','30000000-0000-4000-8000-000000000004',null,7000,1000,'processing',null);
    insert into public.notifications(user_id,category,title_key,body_key) values
      ('${ids.alice}','product_news','a','b'),('${ids.bob}','product_news','a','b');
    insert into public.device_tokens(user_id,token_hash,encrypted_token,environment,locale,timezone) values
      ('${ids.alice}','hash-a','cipher-a','sandbox','en','UTC'),
      ('${ids.bob}','hash-b','cipher-b','sandbox','de','UTC');
    insert into public.moderation_queue(target_type,target_id,source) values('take','${ids.bobTake}','automated');
  `);
}

await applyMigrations();
await seedMatrix();

test('all protected public tables have RLS enabled', async () => {
  const result = await owner(`select count(*)::integer count from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and not c.relrowsecurity`);
  assert.equal(result.rows[0].count, 0);
});

test('private account data is visible only to its owner', async () => {
  assert.equal(await countAs(ids.alice, 'public.user_private', `user_id='${ids.alice}'`), 1);
  assert.equal(await countAs(ids.alice, 'public.user_private', `user_id='${ids.bob}'`), 0);
  assert.equal(await countAs(ids.bob, 'public.user_settings', `user_id='${ids.alice}'`), 0);
});

test('active public profiles are visible but private profiles require an accepted follow', async () => {
  assert.equal(await countAs(ids.alice, 'public.profiles', `id='${ids.privateUser}'`), 0);
  await owner(`insert into public.follows(follower_id,followed_id,status) values('${ids.alice}','${ids.privateUser}','accepted')`);
  assert.equal(await countAs(ids.alice, 'public.profiles', `id='${ids.privateUser}'`), 1);
});

test('blocks symmetrically hide profiles and ranking rows', async () => {
  await owner(`insert into public.blocks(blocker_id,blocked_id) values('${ids.bob}','${ids.alice}')`);
  assert.equal(await countAs(ids.alice, 'public.profiles', `id='${ids.bob}'`), 0);
  assert.equal(await countAs(ids.bob, 'public.profiles', `id='${ids.alice}'`), 0);
  await owner(`delete from public.blocks where blocker_id='${ids.bob}' and blocked_id='${ids.alice}'`);
});

test('takes, attempts and metrics cannot be read across accounts directly', async () => {
  assert.equal(await countAs(ids.alice, 'public.takes', `id='${ids.aliceTake}'`), 1);
  assert.equal(await countAs(ids.alice, 'public.takes', `id='${ids.bobTake}'`), 0);
  assert.equal(await countAs(ids.alice, 'public.take_attempts', `user_id='${ids.bob}'`), 0);
  assert.equal(await countAs(ids.alice, 'public.take_metrics', `take_id='${ids.bobTake}'`), 0);
});

test('feed RPC unlocks and applies world/private/friends scope', async () => {
  const world = await asUser(ids.alice, "select profile_id from public.get_daily_feed('world',50,0)");
  const worldVisible = new Set(world.rows.map((row) => row.profile_id));
  assert(worldVisible.has(ids.bob));
  assert(!worldVisible.has(ids.privateUser), 'private profiles must stay out of world feed');
  const friends = await asUser(ids.alice, "select profile_id from public.get_daily_feed('friends',50,0)");
  assert(new Set(friends.rows.map((row) => row.profile_id)).has(ids.privateUser));
});

test('notification and APNs token rows are isolated per user', async () => {
  assert.equal(await countAs(ids.alice, 'public.notifications'), 1);
  assert.equal(await countAs(ids.alice, 'public.device_tokens'), 1);
  assert.equal(await countAs(ids.bob, 'public.notifications'), 1);
});

test('ordinary users cannot inspect moderation while staff JWT can', async () => {
  assert.equal(await countAs(ids.alice, 'public.moderation_queue'), 0);
  assert.equal(await countAs(ids.admin, 'public.moderation_queue', 'true', 'admin'), 1);
});

test('analytics insert policy rejects forged user ids', async () => {
  await asUser(ids.alice, `insert into public.analytics_events(user_id,event_name) values('${ids.alice}','challenge_viewed')`);
  await assert.rejects(() => asUser(ids.alice,
    `insert into public.analytics_events(user_id,event_name) values('${ids.bob}','challenge_viewed')`));
});

test('storage policy accepts only the reserved owner MP4 path', async () => {
  const valid = `${ids.alice}/30000000-0000-4000-8000-000000000004/${ids.pendingTake}/video.mp4`;
  await asUser(ids.alice, `insert into storage.objects(bucket_id,name) values('takes','${valid}')`);
  await assert.rejects(() => asUser(ids.bob,
    `insert into storage.objects(bucket_id,name) values('takes','${valid}')`));
  await assert.rejects(() => asUser(ids.alice,
    `insert into storage.objects(bucket_id,name) values('takes','${ids.alice}/wrong.mov')`));
});

test('settings RPC changes only the current account', async () => {
  await asUser(ids.alice, "select public.update_user_setting('language_code','\"de\"'::jsonb)");
  const result = await owner(`select user_id,language_code from public.user_settings
    where user_id in ('${ids.alice}','${ids.bob}') order by user_id`);
  assert.equal(result.rows[0].language_code, 'de');
  assert.equal(result.rows[1].language_code, 'en');
});

test('anonymous role has no access to protected profile data', async () => {
  await db.exec('reset role; set role anon');
  await assert.rejects(() => db.query('select * from public.profiles'));
  await db.exec('reset role');
});

test('a finalized take unlocks the feed throughout moderation', async () => {
  const attempt = '30000000-0000-4000-8000-000000000002';
  await owner(`update public.take_attempts set status='upload_reserved',finalized_at=null where id='${attempt}'`);
  await owner(`update public.takes set status='processing' where id='${ids.bobTake}'`);
  let result = await asUser(ids.bob, 'select public.has_valid_take_today() unlocked');
  assert.equal(result.rows[0].unlocked, false, 'a reservation alone must not unlock the feed');

  await owner(`update public.take_attempts set status='finalized',finalized_at=now() where id='${attempt}'`);
  for (const status of ['processing', 'under_review', 'rejected', 'published']) {
    await owner(`update public.takes set status='${status}' where id='${ids.bobTake}'`);
    result = await asUser(ids.bob, 'select public.has_valid_take_today() unlocked');
    assert.equal(result.rows[0].unlocked, true, `finalized ${status} take must unlock the feed`);
  }
});
