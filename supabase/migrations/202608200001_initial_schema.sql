-- SVNLY production schema. Apply through the Supabase CLI; never edit in the dashboard only.
begin;

create extension if not exists pgcrypto;
create extension if not exists citext;

create type public.challenge_status as enum ('draft','scheduled','active','expired','cancelled');
create type public.user_status as enum ('active','restricted','suspended','banned','deletion_pending','deleted');
create type public.take_status as enum ('processing','published','under_review','rejected','removed','deleted');
create type public.attempt_status as enum ('issued','started','upload_reserved','finalized','technical_failure','expired');
create type public.follow_status as enum ('pending','accepted','declined');
create type public.comment_permission as enum ('everyone','followers','disabled');
create type public.report_target as enum ('take','comment','profile');
create type public.report_status as enum ('open','reviewing','resolved','dismissed');
create type public.moderation_decision as enum ('publish','review','reject','hide','remove','warn','suspend','ban');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext not null unique,
  display_name text not null check (char_length(display_name) between 2 and 40),
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  avatar_path text,
  bio text not null default '' check (char_length(bio) <= 160),
  status public.user_status not null default 'active',
  is_private boolean not null default false,
  comment_permission public.comment_permission not null default 'everyone',
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  last_completed_challenge_date date,
  total_takes integer not null default 0 check (total_takes >= 0),
  followers_count integer not null default 0 check (followers_count >= 0),
  following_count integer not null default 0 check (following_count >= 0),
  best_rank integer check (best_rank > 0),
  country_changed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username::text ~ '^[A-Za-z0-9._]{3,20}$'),
  constraint username_not_reserved check (
    lower(username::text) !~ '(svnly|admin|moderator|support|official|security|help)'
  )
);

create table public.user_private (
  user_id uuid primary key references auth.users(id) on delete cascade,
  date_of_birth date,
  age_verified_at timestamptz,
  deletion_requested_at timestamptz,
  deletion_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  language_code text not null default 'en' check (language_code in ('en','de')),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 64),
  auto_delete_days integer check (auto_delete_days in (30,90,365)),
  updated_at timestamptz not null default now()
);

create table public.terms_acceptances (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  document_type text not null check (document_type in ('terms','privacy','guidelines')),
  version text not null,
  accepted_at timestamptz not null default now(),
  unique (user_id, document_type, version)
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  challenge_date date not null unique,
  title_en text not null check (char_length(title_en) between 3 and 120),
  title_de text not null check (char_length(title_de) between 3 and 140),
  description_en text not null default '' check (char_length(description_en) <= 280),
  description_de text not null default '' check (char_length(description_de) <= 320),
  category text not null check (category in ('everyday','funny','creative','reaction','outdoors','food','sound','movement','friends','observation','wholesome','weekend','weird','seasonal','home','workday','pets','view','mood')),
  safety_notes text not null default '',
  status public.challenge_status not null default 'draft',
  publish_at timestamptz not null,
  expires_at timestamptz not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenge_utc_day check (
    publish_at = challenge_date::timestamptz and
    expires_at = challenge_date::timestamptz + interval '1 day'
  )
);

create table public.take_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  nonce uuid not null default gen_random_uuid() unique,
  attempt_number smallint not null default 1 check (attempt_number between 1 and 3),
  retry_count smallint not null default 0 check (retry_count between 0 and 2),
  technical_retry_granted boolean not null default false,
  retry_reason text,
  diagnostics jsonb not null default '{}'::jsonb,
  status public.attempt_status not null default 'issued',
  issued_at timestamptz not null default now(),
  started_at timestamptz,
  expires_at timestamptz not null default now() + interval '10 minutes',
  finalized_at timestamptz,
  unique (user_id, challenge_id, attempt_number)
);

create table public.takes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  attempt_id uuid not null unique references public.take_attempts(id) on delete restrict,
  storage_path text,
  thumbnail_path text,
  duration_ms integer not null check (duration_ms between 6500 and 8000),
  file_size integer not null check (file_size between 1 and 12582912),
  width integer,
  height integer,
  video_codec text,
  audio_codec text,
  live_look text not null default 'Natural',
  status public.take_status not null default 'processing',
  moderation_reason text,
  published_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, challenge_id)
);

create table public.take_metrics (
  take_id uuid primary key references public.takes(id) on delete cascade,
  impressions integer not null default 0,
  completed_views integer not null default 0,
  unique_viewers integer not null default 0,
  reaction_count integer not null default 0,
  unique_commenters integer not null default 0,
  comment_count integer not null default 0,
  ranking_score numeric(12,4) not null default 0,
  updated_at timestamptz not null default now()
);

create table public.reactions (
  user_id uuid not null references auth.users(id) on delete cascade,
  take_id uuid not null references public.takes(id) on delete cascade,
  reaction text not null check (reaction in ('heart','laugh','fire','wow')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, take_id)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  take_id uuid not null references public.takes(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 280 and body !~ '<[^>]*>'),
  status text not null default 'active' check (status in ('active','under_review','removed','deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  status public.follow_status not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

create table public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_type public.report_target not null,
  target_id uuid not null,
  reason text not null check (reason in ('Spam','Harassment','Hate or discrimination','Nudity or sexual content','Minor safety','Violence','Graphic content','Dangerous activity','Illegal activity','Impersonation','Privacy violation','Copyright','Other')),
  details text check (char_length(details) <= 1000),
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (reporter_id, target_type, target_id)
);

create table public.moderation_queue (
  id uuid primary key default gen_random_uuid(),
  target_type public.report_target not null,
  target_id uuid not null,
  source text not null check (source in ('automated','report','appeal','admin')),
  priority smallint not null default 50 check (priority between 0 and 100),
  status text not null default 'open' check (status in ('open','assigned','resolved')),
  automated_scores jsonb not null default '{}'::jsonb,
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  queue_id uuid references public.moderation_queue(id) on delete set null,
  target_type public.report_target not null,
  target_id uuid not null,
  actor_id uuid references auth.users(id) on delete set null,
  decision public.moderation_decision not null,
  reason text not null,
  appeal_of uuid references public.moderation_actions(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.badges (
  id text primary key,
  name_en text not null,
  name_de text not null,
  description_en text not null,
  description_de text not null,
  rule jsonb not null,
  created_at timestamptz not null default now()
);

create table public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null references public.badges(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  context jsonb not null default '{}'::jsonb,
  primary key (user_id, badge_id)
);

create table public.daily_rankings (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  scope text not null check (scope in ('world','country')),
  country_code text not null default '',
  user_id uuid not null references auth.users(id) on delete cascade,
  take_id uuid not null references public.takes(id) on delete cascade,
  rank integer not null check (rank > 0),
  score numeric(12,4) not null,
  calculated_at timestamptz not null default now(),
  primary key (challenge_id, scope, country_code, user_id)
);

create table public.all_time_rankings (
  scope text not null check (scope in ('world','country')),
  country_code text not null default '',
  user_id uuid not null references auth.users(id) on delete cascade,
  rank integer not null check (rank > 0),
  score numeric(14,4) not null,
  calculated_at timestamptz not null default now(),
  primary key (scope, country_code, user_id)
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  encrypted_token text not null,
  environment text not null check (environment in ('sandbox','production')),
  locale text not null,
  timezone text not null,
  last_seen_at timestamptz not null default now(),
  invalidated_at timestamptz
);

create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_challenge_push boolean not null default true,
  streak_push boolean not null default true,
  reaction_push boolean not null default true,
  comment_push boolean not null default true,
  follower_push boolean not null default true,
  moderation_push boolean not null default true,
  product_news_push boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  title_key text not null,
  body_key text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  entitlement_id text not null default 'svnly_plus',
  is_active boolean not null default false,
  product_id text,
  expires_at timestamptz,
  source_event_id text unique,
  updated_at timestamptz not null default now()
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  subject text not null check (char_length(subject) between 3 and 100),
  body text not null check (char_length(body) between 10 and 2000),
  status text not null default 'open' check (status in ('open','waiting','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','processing','complete','failed')),
  requested_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  error_code text
);

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  is_public boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  anonymous_session_id uuid,
  event_name text not null check (event_name in ('onboarding_started','onboarding_completed','signup_started','signup_completed','apple_login_completed','email_login_completed','profile_completed','challenge_viewed','attempt_issued','recording_started','recording_completed','technical_retry','upload_started','upload_completed','moderation_completed','feed_unlocked','feed_video_viewed','reaction_created','comment_created','follow_created','report_created','block_created','streak_incremented','badge_earned','share_started','paywall_viewed','purchase_started','purchase_completed','account_deletion_started','account_deletion_completed')),
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint analytics_no_pii check (
    not (properties ?| array['email','comment','video','body','display_name','username'])
  )
);

create index takes_challenge_status_idx on public.takes(challenge_id,status,created_at desc);
create index attempts_user_challenge_idx on public.take_attempts(user_id,challenge_id,issued_at desc);
create index comments_take_idx on public.comments(take_id,created_at desc) where status = 'active';
create index follows_followed_idx on public.follows(followed_id,status);
create index reports_open_idx on public.reports(status,created_at) where status in ('open','reviewing');
create index moderation_open_idx on public.moderation_queue(priority desc,created_at) where status = 'open';
create index notifications_user_idx on public.notifications(user_id,created_at desc);
create index analytics_event_idx on public.analytics_events(event_name,occurred_at);

commit;
