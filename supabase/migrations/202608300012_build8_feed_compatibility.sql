begin;

-- Build 8 calls has_valid_take_today before get_daily_feed. Completed
-- participation must take a pure read path so storage/feed reads never enter
-- reconciliation or SELECT FOR UPDATE inside a read-only PostgREST transaction.
create or replace function public.has_valid_take_today()
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if exists(
    select 1 from public.challenge_participations p
    join public.challenges c on c.id=p.challenge_id
    where p.user_id=auth.uid() and p.status in ('submitted','processing','completed')
      and c.publish_at<=now() and c.expires_at>now()
  ) then
    return true;
  end if;
  perform public.reconcile_today_participation();
  return exists(
    select 1 from public.challenge_participations p
    join public.challenges c on c.id=p.challenge_id
    where p.user_id=auth.uid() and p.status in ('submitted','processing','completed')
      and c.publish_at<=now() and c.expires_at>now()
  );
end;
$$;

-- Keep the exact Build-8 signature and response model. The stable feed RPC
-- reads only the authoritative participation row and never invokes recovery.
create or replace function public.get_daily_feed(
  p_scope text,p_limit integer default 10,p_offset integer default 0
) returns table(
  id uuid,profile_id uuid,username text,display_name text,
  country_code text,storage_path text,challenge_title text,
  reaction_count integer,comment_count integer,my_reaction text
) language plpgsql stable security definer set search_path = '' as $$
declare v_challenge uuid; v_country text;
begin
  if p_scope not in ('friends','country','world') then raise exception 'invalid_scope'; end if;
  select c.id into v_challenge from public.challenges c
    where c.publish_at<=now() and c.expires_at>now()
      and c.status in ('active','scheduled') order by c.publish_at desc limit 1;
  if v_challenge is null or not exists(
    select 1 from public.challenge_participations cp
    where cp.user_id=auth.uid() and cp.challenge_id=v_challenge
      and cp.status in ('submitted','processing','completed')
  ) then
    raise exception 'feed_locked';
  end if;
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
    and (not p.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=p.id and f.status='accepted'))
  order by coalesce(m.ranking_score,0) desc,t.created_at desc
  limit least(greatest(p_limit,1),20) offset greatest(p_offset,0);
end;
$$;

-- Edge functions use the built-in service role, which bypasses RLS but still
-- requires SQL table privileges. Missing grants caused moderate-take's 403.
grant select,update on public.takes,public.moderation_queue to service_role;
grant select on public.user_settings to service_role;

-- attempt_id is the end-to-end trace identifier already present in the RPC,
-- take row, storage path and participation. Persist every state transition so
-- production traces do not depend on request-body logging.
alter table public.analytics_events drop constraint analytics_events_event_name_check;
alter table public.analytics_events add constraint analytics_events_event_name_check check (event_name in (
  'onboarding_started','onboarding_completed','signup_started','signup_completed',
  'apple_login_completed','email_login_completed','profile_completed','challenge_viewed',
  'attempt_issued','recording_started','recording_completed','technical_retry',
  'upload_started','upload_completed','moderation_completed','feed_unlocked',
  'feed_video_viewed','reaction_created','comment_created','follow_created',
  'report_created','block_created','streak_incremented','badge_earned','share_started',
  'paywall_viewed','purchase_started','purchase_completed','account_deletion_started',
  'account_deletion_completed','participation_transition'
));

create or replace function public.trace_participation_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='INSERT' or old.status is distinct from new.status
     or old.attempt_id is distinct from new.attempt_id
     or old.take_id is distinct from new.take_id then
    insert into public.analytics_events(user_id,event_name,properties)
    values(new.user_id,'participation_transition',jsonb_build_object(
      'trace_id',new.attempt_id,'attempt_id',new.attempt_id,'take_id',new.take_id,
      'challenge_id',new.challenge_id,'status',new.status,'error_code',new.error_code
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists challenge_participation_trace on public.challenge_participations;
create trigger challenge_participation_trace
after insert or update on public.challenge_participations
for each row execute function public.trace_participation_transition();

revoke all on function public.trace_participation_transition() from public,anon,authenticated;

commit;
