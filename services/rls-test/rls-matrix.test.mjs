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
    '202608270011_participation_source_of_truth.sql',
    '202608300012_build8_feed_compatibility.sql',
    '202608300013_my_take_and_profile.sql',
    '202608300014_build11_profile_compatibility.sql',
    '202608300015_social_visibility_guard.sql',
    '202608300016_profile_avatar_persistence.sql',
    '202608300017_moderation_release_gate.sql',
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
    insert into public.challenge_participations(user_id,challenge_id,attempt_id,take_id,status,recorded_at,submitted_at,completed_at) values
      ('${ids.alice}','${ids.challenge}','30000000-0000-4000-8000-000000000001','${ids.aliceTake}','completed',now(),now(),now()),
      ('${ids.bob}','${ids.challenge}','30000000-0000-4000-8000-000000000002','${ids.bobTake}','completed',now(),now(),now()),
      ('${ids.privateUser}','${ids.challenge}','30000000-0000-4000-8000-000000000003','${ids.privateTake}','completed',now(),now(),now()),
      ('${ids.alice}','${ids.tomorrow}','30000000-0000-4000-8000-000000000004','${ids.pendingTake}','uploading',now(),null,null);
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

test('Build 8 feed RPC stays read-only and service moderation can read its take', async () => {
  const definition = await owner(`select pg_get_functiondef('public.get_daily_feed(text,integer,integer)'::regprocedure) body`);
  assert.doesNotMatch(definition.rows[0].body, /has_valid_take_today|reconcile_today_participation/);
  const privileges = await owner(`select
    has_table_privilege('service_role','public.takes','SELECT') takes_select,
    has_table_privilege('service_role','public.takes','UPDATE') takes_update,
    has_table_privilege('service_role','public.moderation_queue','SELECT') queue_select`);
  assert.deepEqual(privileges.rows[0], {takes_select: true, takes_update: true, queue_select: true});
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

test('staff cannot moderate their own take but can decide another users queue item', async () => {
  const adminAttempt = '30000000-0000-4000-8000-000000000008';
  const adminTake = '20000000-0000-4000-8000-000000000008';
  await owner(`insert into public.take_attempts(id,user_id,challenge_id,nonce,status,finalized_at)
    values('${adminAttempt}','${ids.admin}','${ids.challenge}',gen_random_uuid(),'finalized',now())`);
  await owner(`insert into public.takes(id,user_id,challenge_id,attempt_id,storage_path,duration_ms,file_size,status)
    values('${adminTake}','${ids.admin}','${ids.challenge}','${adminAttempt}',
      '${ids.admin}/${adminAttempt}/${adminTake}/video.mp4',7000,1000,'under_review')`);
  const ownQueue = await owner(`insert into public.moderation_queue(target_type,target_id,source)
    values('take','${adminTake}',$1) returning id`, ['automated']);
  await assert.rejects(
    () => asUser(ids.admin,
      `select public.admin_apply_moderation('${ownQueue.rows[0].id}','publish','self approval',null)`, [], 'moderator'),
    /self_moderation_forbidden/,
  );

  const otherQueue = await owner(`select id from public.moderation_queue
    where target_id='${ids.bobTake}' and status='open' limit 1`);
  await asUser(ids.admin,
    `select public.admin_apply_moderation('${otherQueue.rows[0].id}','publish','safe content',null)`, [], 'moderator');
  const decided = await owner(`select t.status,q.status queue_status from public.takes t
    join public.moderation_queue q on q.target_id=t.id where t.id='${ids.bobTake}'`);
  assert.deepEqual(decided.rows[0], {status: 'published', queue_status: 'resolved'});
});

test('a finalized take unlocks the feed throughout moderation', async () => {
  const attempt = '30000000-0000-4000-8000-000000000002';
  await owner(`update public.take_attempts set status='upload_reserved',finalized_at=null where id='${attempt}'`);
  await owner(`update public.takes set status='processing',storage_path=null where id='${ids.bobTake}'`);
  await owner(`update public.challenge_participations set status='uploading',completed_at=null where user_id='${ids.bob}' and challenge_id='${ids.challenge}'`);
  let result = await asUser(ids.bob, 'select public.has_valid_take_today() unlocked');
  assert.equal(result.rows[0].unlocked, false, 'a reservation alone must not unlock the feed');

  await owner(`update public.take_attempts set status='finalized',finalized_at=now() where id='${attempt}'`);
  await owner(`update public.takes set storage_path='${ids.bob}/${attempt}/${ids.bobTake}/video.mp4' where id='${ids.bobTake}'`);
  for (const status of ['processing', 'under_review', 'rejected', 'published']) {
    await owner(`update public.takes set status='${status}' where id='${ids.bobTake}'`);
    result = await asUser(ids.bob, 'select public.has_valid_take_today() unlocked');
    assert.equal(result.rows[0].unlocked, true, `finalized ${status} take must unlock the feed`);
  }
});

test('recording upload and finalize atomically unlock participation without duplicate takes', async () => {
  const user = '00000000-0000-4000-8000-000000000005';
  const attempt = '30000000-0000-4000-8000-000000000005';
  await owner(`insert into auth.users(id) values('${user}')`);
  await owner(`insert into public.take_attempts(id,user_id,challenge_id,nonce,status,started_at)
    values('${attempt}','${user}','${ids.challenge}','40000000-0000-4000-8000-000000000005','started',now())`);
  const first = await asUser(user, `select public.reserve_take_upload('${attempt}','40000000-0000-4000-8000-000000000005',7000,1000,'Natural') id`);
  const second = await asUser(user, `select public.reserve_take_upload('${attempt}','40000000-0000-4000-8000-000000000005',7000,1000,'Natural') id`);
  assert.equal(first.rows[0].id, second.rows[0].id);
  assert.equal((await owner(`select count(*)::integer count from public.takes where user_id='${user}' and challenge_id='${ids.challenge}'`)).rows[0].count, 1);
  const take = first.rows[0].id;
  const path = `${user}/${attempt}/${take}/video.mp4`;
  await asUser(user, `insert into storage.objects(bucket_id,name,owner_id) values('takes','${path}','${user}')`);
  await asUser(user, `select public.finalize_take('${take}','${attempt}','${path}',7000,1000)`);
  assert.equal((await asUser(user, 'select public.has_valid_take_today() unlocked')).rows[0].unlocked, true);
  const participation = await owner(`select status from public.challenge_participations where user_id='${user}' and challenge_id='${ids.challenge}'`);
  assert.equal(participation.rows[0].status, 'completed');
  const trace = await owner(`select properties from public.analytics_events where user_id='${user}' and event_name='participation_transition' and properties->>'status'='completed' order by occurred_at desc limit 1`);
  assert.equal(trace.rows[0].properties.trace_id, attempt);
});

test('lost finalize response and app termination reconcile uploaded storage into an unlocked take', async () => {
  const user = '00000000-0000-4000-8000-000000000006';
  const attempt = '30000000-0000-4000-8000-000000000006';
  const take = '20000000-0000-4000-8000-000000000006';
  const path = `${user}/${attempt}/${take}/video.mp4`;
  await owner(`insert into auth.users(id) values('${user}')`);
  await owner(`insert into public.take_attempts(id,user_id,challenge_id,nonce,status,started_at)
    values('${attempt}','${user}','${ids.challenge}',gen_random_uuid(),'upload_reserved',now())`);
  await owner(`insert into public.takes(id,user_id,challenge_id,attempt_id,duration_ms,file_size,status)
    values('${take}','${user}','${ids.challenge}','${attempt}',7000,1000,'processing')`);
  await asUser(user, `insert into storage.objects(bucket_id,name,owner_id) values('takes','${path}','${user}')`);
  assert.equal((await asUser(user, 'select public.reconcile_today_participation() unlocked')).rows[0].unlocked, true);
  const repaired = await owner(`select a.status attempt_status,t.status take_status,t.storage_path,p.status participation_status
    from public.take_attempts a join public.takes t on t.attempt_id=a.id
    join public.challenge_participations p on p.take_id=t.id where t.id='${take}'`);
  assert.deepEqual(repaired.rows[0], {attempt_status: 'finalized', take_status: 'processing', storage_path: path, participation_status: 'completed'});
  for (const status of ['processing', 'under_review', 'rejected']) {
    await owner(`update public.takes set status='${status}' where id='${take}'`);
    assert.equal((await asUser(user, 'select public.has_valid_take_today() unlocked')).rows[0].unlocked, true);
  }
});

test('expired technical attempt without a take is automatically eligible for retry', async () => {
  const user = '00000000-0000-4000-8000-000000000007';
  const attempt = '30000000-0000-4000-8000-000000000007';
  await owner(`insert into auth.users(id) values('${user}')`);
  await owner(`insert into public.profiles(id,username,display_name,country_code) values('${user}','retry.user','Retry User','CH')`);
  await owner(`update public.user_private set age_verified_at=now() where user_id='${user}'`);
  await owner(`insert into public.terms_acceptances(user_id,document_type,version) values
    ('${user}','terms','1'),('${user}','privacy','1'),('${user}','guidelines','1')`);
  await owner(`insert into public.take_attempts(id,user_id,challenge_id,nonce,status,expires_at)
    values('${attempt}','${user}','${ids.challenge}',gen_random_uuid(),'expired',now()-interval '1 minute')`);
  const retry = await asUser(user, 'select * from public.issue_take_attempt()');
  assert.equal(retry.rows.length, 1);
  assert.equal(retry.rows[0].retry_count, 1);
  const previous = await owner(`select status,technical_retry_granted from public.take_attempts where id='${attempt}'`);
  assert.deepEqual(previous.rows[0], {status: 'technical_failure', technical_retry_granted: true});
});

test('owner My Take RPC exposes playable history and moderation state only for self', async () => {
  const alice = await asUser(ids.alice, 'select * from public.get_my_takes(30)');
  assert.equal(alice.rows.length, 2);
  const today = alice.rows.find((row) => row.challenge_id === ids.challenge);
  assert.equal(today.id, ids.aliceTake);
  assert.equal(today.take_status, 'published');
  assert.equal(today.participation_status, 'completed');
  assert.equal(today.is_today, true);
  const bob = await asUser(ids.bob, 'select * from public.get_my_takes(30)');
  assert.deepEqual(new Set(bob.rows.map((row) => row.id)), new Set([ids.bobTake]));
});

test('Build 11 profile response remains backward compatible during rollout', async () => {
  const result = await asUser(ids.alice, 'select public.get_my_profile() profile');
  const profile = result.rows[0].profile;
  assert(Array.isArray(profile.badges));
  assert(Array.isArray(profile.take_history));
  assert.equal(profile.take_history[0].id, ids.aliceTake);
  assert.equal(profile.avatar_path, null);
});

test('reaction and comment on a published take update metrics and notify its owner', async () => {
  await asUser(ids.bob, `select public.set_reaction('${ids.aliceTake}','fire')`);
  await asUser(ids.bob, `select public.create_comment('${ids.aliceTake}','Lowkey iconic')`);
  const metrics = await owner(`select reaction_count,comment_count from public.take_metrics where take_id='${ids.aliceTake}'`);
  assert.deepEqual(metrics.rows[0], {reaction_count: 1, comment_count: 1});
  const notifications = await owner(`select category from public.notifications where user_id='${ids.alice}' and category in ('reaction','comment') order by category`);
  assert.deepEqual(notifications.rows.map((row) => row.category), ['comment', 'reaction']);
});

test('social RPCs require feed participation and take visibility', async () => {
  const hidden = await asUser(ids.admin, `select * from public.get_comments('${ids.aliceTake}',30,0)`);
  assert.equal(hidden.rows.length, 0);
  await assert.rejects(() => asUser(ids.admin,
    `select public.set_reaction('${ids.aliceTake}','heart')`));
  await assert.rejects(() => asUser(ids.admin,
    `select public.create_comment('${ids.aliceTake}','Guessed UUID')`));
});

test('avatar upload, replacement, restart persistence and removal are owner-scoped', async () => {
  const firstPath = `${ids.alice}/avatar-11111111-1111-4111-8111-111111111111.jpg`;
  const secondPath = `${ids.alice}/avatar-22222222-2222-4222-8222-222222222222.jpg`;

  await asUser(ids.alice, `insert into storage.objects(bucket_id,name,owner_id) values('avatars','${firstPath}','${ids.alice}')`);
  assert.equal(await countAs(ids.alice, 'storage.objects', `bucket_id='avatars' and name='${firstPath}'`), 1,
    'the owner must be able to read a just-uploaded object before profiles.avatar_path changes');
  assert.equal(await countAs(ids.bob, 'storage.objects',
    `bucket_id='avatars' and name='${firstPath}'`), 0);

  const firstSave = await asUser(ids.alice,
    `select public.update_my_profile('alice.glow','Alice Glow','Seven seconds, no overthinking.','CH','${firstPath}',false) profile`);
  assert.equal(firstSave.rows[0].profile.avatar_path, firstPath);
  assert.equal(firstSave.rows[0].profile.previous_avatar_path, null);

  await asUser(ids.alice, `insert into storage.objects(bucket_id,name,owner_id) values('avatars','${secondPath}','${ids.alice}')`);
  const replacement = await asUser(ids.alice,
    `select public.update_my_profile('alice.glow','Alice Reloaded','Still here after restart.','CH','${secondPath}',false) profile`);
  assert.equal(replacement.rows[0].profile.avatar_path, secondPath);
  assert.equal(replacement.rows[0].profile.previous_avatar_path, firstPath);

  // A fresh authenticated transaction models a full app restart.
  const reloaded = await asUser(ids.alice, 'select public.get_my_profile() profile');
  assert.equal(reloaded.rows[0].profile.avatar_path, secondPath);
  assert.equal(reloaded.rows[0].profile.display_name, 'Alice Reloaded');
  assert.equal(reloaded.rows[0].profile.bio, 'Still here after restart.');

  const removed = await asUser(ids.alice,
    `select public.update_my_profile('alice.glow','Alice Reloaded','Still here after restart.','CH',null,true) profile`);
  assert.equal(removed.rows[0].profile.avatar_path, null);
  assert.equal(removed.rows[0].profile.previous_avatar_path, secondPath);
  await asUser(ids.alice,
    `delete from storage.objects where bucket_id='avatars' and name in ('${firstPath}','${secondPath}')`);
  assert.equal((await owner(`select count(*)::integer count from storage.objects where bucket_id='avatars' and name in ('${firstPath}','${secondPath}')`)).rows[0].count, 0);

  await assert.rejects(() => asUser(ids.bob,
    `select public.update_my_profile('bob.real','Bob','Nope','DE','${firstPath}',false)`));
});
