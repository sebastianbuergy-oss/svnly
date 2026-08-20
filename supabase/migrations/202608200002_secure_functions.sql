begin;

create or replace function public.current_user_role()
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'user');
$$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.current_user_role() in ('admin','moderator');
$$;

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
for each row execute function public.touch_updated_at();
create trigger user_private_touch before update on public.user_private
for each row execute function public.touch_updated_at();
create trigger challenges_touch before update on public.challenges
for each row execute function public.touch_updated_at();
create trigger takes_touch before update on public.takes
for each row execute function public.touch_updated_at();
create trigger comments_touch before update on public.comments
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_private(user_id) values (new.id);
  insert into public.user_settings(user_id) values (new.id);
  insert into public.notification_preferences(user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.complete_profile(
  p_username text,
  p_display_name text,
  p_country_code text,
  p_language_code text,
  p_timezone text,
  p_date_of_birth date,
  p_is_private boolean,
  p_terms_version text,
  p_privacy_version text,
  p_guidelines_version text
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  if p_date_of_birth > ((now() at time zone 'utc')::date - interval '16 years')::date then
    raise exception 'minimum_age_16';
  end if;
  if p_username !~ '^[A-Za-z0-9._]{3,20}$'
     or lower(p_username) ~ '(svnly|admin|moderator|support|official|security|help)' then
    raise exception 'invalid_username';
  end if;
  insert into public.profiles(id,username,display_name,country_code,is_private)
  values (v_user,p_username,p_display_name,upper(p_country_code),p_is_private)
  on conflict (id) do update set
    username = excluded.username,
    display_name = excluded.display_name,
    is_private = excluded.is_private,
    country_code = case
      when public.profiles.country_changed_at is null
        or public.profiles.country_changed_at < now() - interval '30 days'
      then excluded.country_code else public.profiles.country_code end,
    country_changed_at = case
      when public.profiles.country_code <> excluded.country_code then now()
      else public.profiles.country_changed_at end;
  update public.user_private set
    date_of_birth = p_date_of_birth,
    age_verified_at = now()
  where user_id = v_user;
  update public.user_settings set
    language_code = p_language_code,
    timezone = p_timezone
  where user_id = v_user;
  insert into public.terms_acceptances(user_id,document_type,version) values
    (v_user,'terms',p_terms_version),
    (v_user,'privacy',p_privacy_version),
    (v_user,'guidelines',p_guidelines_version)
  on conflict do nothing;
end;
$$;

create or replace function public.current_challenge()
returns table(
  id uuid, challenge_date date, title_en text, title_de text,
  description_en text, description_de text, category text,
  expires_at timestamptz, participant_count bigint
) language sql stable security definer set search_path = '' as $$
  select c.id,c.challenge_date,c.title_en,c.title_de,c.description_en,
    c.description_de,c.category,c.expires_at,
    count(t.id) filter (where t.status in ('processing','published','under_review'))
  from public.challenges c
  left join public.takes t on t.challenge_id = c.id
  where c.publish_at <= now() and c.expires_at > now()
    and c.status in ('active','scheduled')
  group by c.id
  limit 1;
$$;

create or replace function public.has_valid_take_today()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.takes t
    join public.challenges c on c.id = t.challenge_id
    where t.user_id = auth.uid()
      and c.publish_at <= now() and c.expires_at > now()
      and t.status in ('processing','published','under_review')
  );
$$;

create or replace function public.issue_take_attempt()
returns table(attempt_id uuid, nonce uuid, expires_at timestamptz, retry_count smallint)
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_challenge uuid;
  v_attempt public.take_attempts%rowtype;
  v_count integer;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select c.id into v_challenge from public.challenges c
    where c.publish_at <= now() and c.expires_at > now()
      and c.status in ('active','scheduled') limit 1;
  if v_challenge is null then raise exception 'no_active_challenge'; end if;
  if not exists (
    select 1 from public.profiles p join public.user_private u on u.user_id=p.id
    where p.id=v_user and p.status='active' and u.age_verified_at is not null
      and exists(select 1 from public.terms_acceptances a where a.user_id=v_user and a.document_type='terms')
      and exists(select 1 from public.terms_acceptances a where a.user_id=v_user and a.document_type='privacy')
      and exists(select 1 from public.terms_acceptances a where a.user_id=v_user and a.document_type='guidelines')
  ) then raise exception 'profile_not_eligible'; end if;
  if exists(select 1 from public.takes where user_id=v_user and challenge_id=v_challenge) then
    raise exception 'take_already_exists';
  end if;
  select * into v_attempt from public.take_attempts
    where user_id=v_user and challenge_id=v_challenge order by attempt_number desc limit 1 for update;
  if found and v_attempt.status='issued' and v_attempt.expires_at > now() then
    raise exception 'attempt_already_active';
  end if;
  if found and v_attempt.status in ('started','upload_reserved','finalized') then
    raise exception 'attempt_consumed';
  end if;
  if found and not v_attempt.technical_retry_granted then
    raise exception 'technical_retry_not_granted';
  end if;
  select count(*) into v_count from public.take_attempts where user_id=v_user and challenge_id=v_challenge;
  if v_count >= 3 then raise exception 'retry_limit_reached'; end if;
  insert into public.take_attempts(user_id,challenge_id,attempt_number,retry_count)
  values(v_user,v_challenge,v_count+1,greatest(v_count,0))
  returning id,public.take_attempts.nonce,public.take_attempts.expires_at,public.take_attempts.retry_count
  into attempt_id,nonce,expires_at,retry_count;
  return next;
end;
$$;

create or replace function public.mark_attempt_started(p_attempt_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.take_attempts set status='started',started_at=now()
  where id=p_attempt_id and user_id=auth.uid() and status='issued' and expires_at > now();
  if not found then raise exception 'attempt_not_startable'; end if;
end;
$$;

create or replace function public.request_technical_retry(
  p_attempt_id uuid, p_reason text, p_diagnostics jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_attempt public.take_attempts%rowtype;
begin
  if p_reason not in ('camera_initialization_failed','camera_or_recording_error','duration_out_of_tolerance','app_backgrounded','file_corrupt','upload_failed','server_rejected_technical') then
    raise exception 'invalid_retry_reason';
  end if;
  select * into v_attempt from public.take_attempts
    where id=p_attempt_id and user_id=auth.uid() for update;
  if not found or v_attempt.status not in ('issued','started','upload_reserved') then
    raise exception 'retry_not_available';
  end if;
  if v_attempt.retry_count >= 2 then raise exception 'retry_limit_reached'; end if;
  if exists(select 1 from public.takes where attempt_id=p_attempt_id and storage_path is not null) then
    raise exception 'recorded_file_exists';
  end if;
  delete from public.takes where attempt_id=p_attempt_id and storage_path is null;
  update public.take_attempts set
    status='technical_failure',technical_retry_granted=true,
    retry_reason=p_reason,
    diagnostics=jsonb_build_object(
      'reason',p_reason,'elapsed_ms',p_diagnostics->'elapsed_ms',
      'app_state',p_diagnostics->'app_state','recorded_at',now()
    )
  where id=p_attempt_id;
  insert into public.analytics_events(user_id,event_name,properties)
  values(auth.uid(),'technical_retry',jsonb_build_object('reason',p_reason));
end;
$$;

create or replace function public.reserve_take_upload(
  p_attempt_id uuid, p_nonce uuid, p_duration_ms integer,
  p_file_size integer, p_look text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_attempt public.take_attempts%rowtype;
  v_take uuid;
begin
  select * into v_attempt from public.take_attempts
    where id=p_attempt_id and user_id=auth.uid() and nonce=p_nonce for update;
  if not found or v_attempt.status <> 'started' then raise exception 'invalid_attempt'; end if;
  if p_duration_ms not between 6800 and 7600 then raise exception 'invalid_duration'; end if;
  if p_file_size not between 1 and 12582912 then raise exception 'invalid_file_size'; end if;
  insert into public.takes(user_id,challenge_id,attempt_id,duration_ms,file_size,live_look)
  values(auth.uid(),v_attempt.challenge_id,p_attempt_id,p_duration_ms,p_file_size,p_look)
  on conflict (attempt_id) do update set duration_ms=excluded.duration_ms
  returning id into v_take;
  update public.take_attempts set status='upload_reserved' where id=p_attempt_id;
  return v_take;
end;
$$;

create or replace function public.finalize_take(
  p_take_id uuid, p_attempt_id uuid, p_storage_path text,
  p_duration_ms integer, p_file_size integer
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_take public.takes%rowtype;
begin
  select * into v_take from public.takes
    where id=p_take_id and attempt_id=p_attempt_id and user_id=auth.uid() for update;
  if not found then raise exception 'take_not_found'; end if;
  if v_take.storage_path is not null then
    if v_take.storage_path = p_storage_path then return; end if;
    raise exception 'take_already_finalized';
  end if;
  if split_part(p_storage_path,'/',1) <> auth.uid()::text
     or right(lower(p_storage_path),4) <> '.mp4' then raise exception 'invalid_storage_path'; end if;
  if p_duration_ms not between 6800 and 7600 or p_file_size not between 1 and 12582912 then
    raise exception 'invalid_media';
  end if;
  update public.takes set storage_path=p_storage_path,status='processing' where id=p_take_id;
  update public.take_attempts set status='finalized',finalized_at=now() where id=p_attempt_id;
  insert into public.take_metrics(take_id) values(p_take_id) on conflict do nothing;
  insert into public.moderation_queue(target_type,target_id,source,priority)
    values('take',p_take_id,'automated',60);
  insert into public.analytics_events(user_id,event_name,properties)
    values(auth.uid(),'upload_completed',jsonb_build_object('duration_ms',p_duration_ms,'size_bucket_kb',(p_file_size/1024/256)*256));
end;
$$;

create or replace function public.get_daily_feed(
  p_scope text, p_limit integer default 10, p_offset integer default 0
) returns table(
  id uuid, profile_id uuid, username text, display_name text,
  country_code text, storage_path text, challenge_title text,
  reaction_count integer, comment_count integer, my_reaction text
) language plpgsql stable security definer set search_path = '' as $$
declare v_challenge uuid; v_country text;
begin
  if p_scope not in ('friends','country','world') then raise exception 'invalid_scope'; end if;
  if not public.has_valid_take_today() then raise exception 'feed_locked'; end if;
  select c.id into v_challenge from public.challenges c
    where c.publish_at <= now() and c.expires_at > now() limit 1;
  select p.country_code into v_country from public.profiles p where p.id=auth.uid();
  return query
  select t.id,p.id,p.username::text,p.display_name,p.country_code,t.storage_path,c.title_en,
    coalesce(m.reaction_count,0),coalesce(m.comment_count,0),r.reaction
  from public.takes t
  join public.profiles p on p.id=t.user_id
  join public.challenges c on c.id=t.challenge_id
  left join public.take_metrics m on m.take_id=t.id
  left join public.reactions r on r.take_id=t.id and r.user_id=auth.uid()
  where t.challenge_id=v_challenge and t.status='published'
    and not public.is_blocked(auth.uid(),t.user_id)
    and (
      (p_scope='friends' and exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=t.user_id and f.status='accepted'))
      or (p_scope='country' and not p.is_private and p.country_code=v_country)
      or (p_scope='world' and not p.is_private)
    )
    and (not p.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=t.user_id and f.status='accepted'))
  order by coalesce(m.ranking_score,0) desc,t.created_at desc
  limit least(greatest(p_limit,1),20) offset greatest(p_offset,0);
end;
$$;

create or replace function public.set_reaction(p_take_id uuid,p_reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select user_id into v_owner from public.takes where id=p_take_id and status='published';
  if v_owner is null or v_owner=auth.uid() or public.is_blocked(auth.uid(),v_owner) then raise exception 'reaction_not_allowed'; end if;
  if p_reaction is null then delete from public.reactions where user_id=auth.uid() and take_id=p_take_id;
  elsif p_reaction in ('heart','laugh','fire','wow') then
    insert into public.reactions(user_id,take_id,reaction) values(auth.uid(),p_take_id,p_reaction)
    on conflict(user_id,take_id) do update set reaction=excluded.reaction,updated_at=now();
  else raise exception 'invalid_reaction'; end if;
  update public.take_metrics set reaction_count=(select count(*) from public.reactions where take_id=p_take_id),updated_at=now() where take_id=p_take_id;
end;
$$;

create or replace function public.create_comment(p_take_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_owner uuid; v_permission public.comment_permission; v_id uuid;
begin
  if char_length(trim(p_body)) not between 1 and 280 or p_body ~ '<[^>]*>' then raise exception 'invalid_comment'; end if;
  if (select count(*) from public.comments where user_id=auth.uid() and created_at>now()-interval '1 minute') >= 5 then raise exception 'comment_rate_limit'; end if;
  select t.user_id,p.comment_permission into v_owner,v_permission from public.takes t join public.profiles p on p.id=t.user_id where t.id=p_take_id and t.status='published';
  if v_owner is null or public.is_blocked(auth.uid(),v_owner) or v_permission='disabled' then raise exception 'comments_disabled'; end if;
  if v_permission='followers' and not exists(select 1 from public.follows where follower_id=auth.uid() and followed_id=v_owner and status='accepted') then raise exception 'followers_only'; end if;
  insert into public.comments(user_id,take_id,body) values(auth.uid(),p_take_id,trim(p_body)) returning id into v_id;
  update public.take_metrics set comment_count=(select count(*) from public.comments where take_id=p_take_id and status='active'),unique_commenters=(select count(distinct user_id) from public.comments where take_id=p_take_id and status='active') where take_id=p_take_id;
  return v_id;
end;
$$;

create or replace function public.get_comments(p_take_id uuid,p_limit integer default 30,p_offset integer default 0)
returns table(id uuid,profile_id uuid,username text,body text,created_at timestamptz,is_mine boolean)
language sql stable security definer set search_path = '' as $$
  select c.id,p.id,p.username::text,c.body,c.created_at,c.user_id=auth.uid()
  from public.comments c join public.profiles p on p.id=c.user_id
  where c.take_id=p_take_id and c.status='active' and not public.is_blocked(auth.uid(),c.user_id)
  order by c.created_at desc limit least(p_limit,50) offset greatest(p_offset,0);
$$;

create or replace function public.delete_comment(p_comment_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.comments c set status='deleted',body='[deleted]',deleted_at=now()
  where c.id=p_comment_id and (c.user_id=auth.uid() or exists(select 1 from public.takes t where t.id=c.take_id and t.user_id=auth.uid()));
  if not found then raise exception 'delete_not_allowed'; end if;
end;
$$;

create or replace function public.recount_follow_totals(p_user uuid)
returns void language sql security definer set search_path = '' as $$
  update public.profiles set
    followers_count=(select count(*) from public.follows where followed_id=p_user and status='accepted'),
    following_count=(select count(*) from public.follows where follower_id=p_user and status='accepted')
  where id=p_user;
$$;

create or replace function public.follow_profile(p_profile_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare v_status public.follow_status;
begin
  if p_profile_id=auth.uid() or public.is_blocked(auth.uid(),p_profile_id) then raise exception 'follow_not_allowed'; end if;
  select case when is_private then 'pending'::public.follow_status else 'accepted'::public.follow_status end into v_status from public.profiles where id=p_profile_id and status='active';
  if v_status is null then raise exception 'profile_not_found'; end if;
  insert into public.follows(follower_id,followed_id,status) values(auth.uid(),p_profile_id,v_status)
  on conflict(follower_id,followed_id) do update set status=excluded.status,updated_at=now();
  perform public.recount_follow_totals(auth.uid()); perform public.recount_follow_totals(p_profile_id);
  return v_status::text;
end;
$$;

create or replace function public.block_profile(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_profile_id=auth.uid() then raise exception 'cannot_block_self'; end if;
  insert into public.blocks(blocker_id,blocked_id) values(auth.uid(),p_profile_id) on conflict do nothing;
  delete from public.follows where (follower_id=auth.uid() and followed_id=p_profile_id) or (follower_id=p_profile_id and followed_id=auth.uid());
  perform public.recount_follow_totals(auth.uid()); perform public.recount_follow_totals(p_profile_id);
end;
$$;

create or replace function public.unblock_profile(p_profile_id uuid)
returns void language sql security definer set search_path = '' as $$
  delete from public.blocks where blocker_id=auth.uid() and blocked_id=p_profile_id;
$$;

create or replace function public.get_blocked_users()
returns table(profile_id uuid,username text,display_name text)
language sql stable security definer set search_path = '' as $$
  select p.id,p.username::text,p.display_name from public.blocks b join public.profiles p on p.id=b.blocked_id where b.blocker_id=auth.uid() order by b.created_at desc;
$$;

create or replace function public.create_report(p_target_type text,p_target_id uuid,p_reason text,p_details text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_target_type not in ('take','comment','profile') then raise exception 'invalid_target'; end if;
  insert into public.reports(reporter_id,target_type,target_id,reason,details)
  values(auth.uid(),p_target_type::public.report_target,p_target_id,p_reason,p_details)
  on conflict(reporter_id,target_type,target_id) do update set reason=excluded.reason,details=excluded.details,status='open',resolved_at=null
  returning id into v_id;
  insert into public.moderation_queue(target_type,target_id,source,priority) values(p_target_type::public.report_target,p_target_id,'report',70);
  return v_id;
end;
$$;

create or replace function public.get_rankings(p_period text,p_scope text,p_limit integer default 100)
returns table(rank integer,user_id uuid,username text,display_name text,country_code text,score numeric)
language plpgsql stable security definer set search_path = '' as $$
declare v_country text; v_challenge uuid;
begin
  select country_code into v_country from public.profiles where id=auth.uid();
  select id into v_challenge from public.challenges where publish_at<=now() and expires_at>now() limit 1;
  if p_period='today' then
    return query select r.rank,r.user_id,p.username::text,p.display_name,p.country_code,r.score
    from public.daily_rankings r join public.profiles p on p.id=r.user_id
    where r.challenge_id=v_challenge and r.scope=case when p_scope='country' then 'country' else 'world' end
      and (p_scope<>'country' or r.country_code=v_country)
      and (p_scope<>'friends' or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=r.user_id and f.status='accepted'))
      and not public.is_blocked(auth.uid(),r.user_id)
    order by r.rank limit least(p_limit,100);
  elsif p_period='all_time' then
    return query select r.rank,r.user_id,p.username::text,p.display_name,p.country_code,r.score
    from public.all_time_rankings r join public.profiles p on p.id=r.user_id
    where r.scope=case when p_scope='country' then 'country' else 'world' end
      and (p_scope<>'country' or r.country_code=v_country)
      and (p_scope<>'friends' or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=r.user_id and f.status='accepted'))
      and not public.is_blocked(auth.uid(),r.user_id)
    order by r.rank limit least(p_limit,100);
  else raise exception 'invalid_period'; end if;
end;
$$;

create or replace function public.get_my_profile()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id',p.id,'username',p.username,'display_name',p.display_name,'country_code',p.country_code,
    'bio',p.bio,'total_takes',p.total_takes,'followers_count',p.followers_count,
    'following_count',p.following_count,'current_streak',p.current_streak,
    'longest_streak',p.longest_streak,'best_rank',p.best_rank,
    'badges',coalesce((select jsonb_agg(b.name_en order by ub.awarded_at) from public.user_badges ub join public.badges b on b.id=ub.badge_id where ub.user_id=p.id),'[]'::jsonb),
    'take_history',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'challenge_title',c.title_en,'challenge_date',c.challenge_date,'rank',r.rank) order by c.challenge_date desc) from public.takes t join public.challenges c on c.id=t.challenge_id left join public.daily_rankings r on r.take_id=t.id and r.scope='world' and r.country_code='' where t.user_id=p.id and t.status='published'),'[]'::jsonb)
  ) from public.profiles p where p.id=auth.uid();
$$;

create or replace function public.update_user_setting(p_key text,p_value jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  case p_key
    when 'language_code' then update public.user_settings set language_code=trim(both '"' from p_value::text) where user_id=auth.uid();
    when 'is_private' then update public.profiles set is_private=(p_value::text)::boolean where id=auth.uid();
    when 'comment_permission' then update public.profiles set comment_permission=trim(both '"' from p_value::text)::public.comment_permission where id=auth.uid();
    when 'auto_delete_days' then update public.user_settings set auto_delete_days=case when p_value='null'::jsonb then null else (p_value::text)::integer end where user_id=auth.uid();
    when 'daily_challenge_push' then update public.notification_preferences set daily_challenge_push=(p_value::text)::boolean where user_id=auth.uid();
    when 'streak_push' then update public.notification_preferences set streak_push=(p_value::text)::boolean where user_id=auth.uid();
    when 'reaction_push' then update public.notification_preferences set reaction_push=(p_value::text)::boolean where user_id=auth.uid();
    when 'comment_push' then update public.notification_preferences set comment_push=(p_value::text)::boolean where user_id=auth.uid();
    when 'follower_push' then update public.notification_preferences set follower_push=(p_value::text)::boolean where user_id=auth.uid();
    when 'moderation_push' then update public.notification_preferences set moderation_push=(p_value::text)::boolean where user_id=auth.uid();
    when 'product_news_push' then update public.notification_preferences set product_news_push=(p_value::text)::boolean where user_id=auth.uid();
    else raise exception 'setting_not_allowed';
  end case;
end;
$$;

create or replace function public.create_support_ticket(p_subject text,p_body text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if (select count(*) from public.support_tickets where user_id=auth.uid() and created_at>now()-interval '1 day') >= 5 then raise exception 'support_rate_limit'; end if;
  insert into public.support_tickets(user_id,subject,body) values(auth.uid(),trim(p_subject),trim(p_body)) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.request_account_deletion()
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  update public.profiles set status='deletion_pending' where id=auth.uid();
  update public.user_private set deletion_requested_at=now() where user_id=auth.uid();
  insert into public.account_deletion_jobs(user_id) values(auth.uid())
  on conflict(user_id) do update set status='pending',requested_at=now(),error_code=null
  returning id into v_id;
  return v_id;
end;
$$;

insert into public.badges(id,name_en,name_de,description_en,description_de,rule) values
('first_take','FIRST TAKE','ERSTER TAKE','Completed a first valid take.','Ersten gültigen Take abgeschlossen.','{"total_takes":1}'),
('streak_7','7 DAY STREAK','7-TAGE-STREAK','Seven consecutive global challenges.','Sieben globale Challenges in Folge.','{"streak":7}'),
('streak_30','30 DAY STREAK','30-TAGE-STREAK','Thirty consecutive challenges.','Dreissig Challenges in Folge.','{"streak":30}'),
('streak_100','100 DAY STREAK','100-TAGE-STREAK','One hundred consecutive challenges.','Hundert Challenges in Folge.','{"streak":100}'),
('takes_10','10 TAKES','10 TAKES','Ten valid takes.','Zehn gültige Takes.','{"total_takes":10}'),
('takes_50','50 TAKES','50 TAKES','Fifty valid takes.','Fünfzig gültige Takes.','{"total_takes":50}'),
('takes_100','100 TAKES','100 TAKES','One hundred valid takes.','Hundert gültige Takes.','{"total_takes":100}'),
('top_100','TOP 100','TOP 100','Reached the daily world top 100.','Die täglichen World Top 100 erreicht.','{"rank_lte":100}'),
('top_10','TOP 10','TOP 10','Reached the daily world top 10.','Die täglichen World Top 10 erreicht.','{"rank_lte":10}'),
('world_1','WORLD #1','WORLD #1','Ranked first worldwide.','Weltweit Rang eins erreicht.','{"world_rank":1}'),
('country_1','COUNTRY #1','COUNTRY #1','Ranked first in a country.','In einem Land Rang eins erreicht.','{"country_rank":1}'),
('early_adopter','EARLY ADOPTER','EARLY ADOPTER','Joined during the launch period.','Während der Startphase beigetreten.','{"manual":true}'),
('real_one','REAL ONE','REAL ONE','A special community recognition.','Eine besondere Community-Auszeichnung.','{"manual":true}')
on conflict do nothing;

insert into public.app_config(key,value,is_public) values
('minimum_ios_version','"16.0"',true),
('minimum_app_version','"1.0.0"',true),
('premium_enabled','false',true),
('maintenance_mode','false',true)
on conflict do nothing;

commit;
