begin;

create table public.challenge_participations (
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  attempt_id uuid references public.take_attempts(id) on delete set null,
  take_id uuid references public.takes(id) on delete set null,
  status text not null check (status in (
    'attempt_started','recorded','uploading','submitted','processing','completed','failed_technical'
  )),
  error_code text,
  recorded_at timestamptz,
  submitted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, challenge_id),
  unique (take_id)
);

alter table public.challenge_participations enable row level security;
create policy participations_self_read on public.challenge_participations
  for select to authenticated using (user_id=auth.uid() or public.is_staff());
revoke insert,update,delete on public.challenge_participations from anon,authenticated;
grant select on public.challenge_participations to authenticated;

-- The previous ranking refresh used an unqualified DELETE. Production's
-- safe-update guard rejected it from the take INSERT trigger and rolled the
-- complete upload reservation back.
create or replace function public.refresh_take_ranking(p_take_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_take public.takes%rowtype;
  v_impressions integer;
  v_completed integer;
  v_reactions integer;
  v_commenters integer;
  v_score numeric(12,4);
begin
  select * into v_take from public.takes where id=p_take_id;
  if not found then return; end if;

  select count(*),count(*) filter(where completed)
    into v_impressions,v_completed from public.take_views where take_id=p_take_id;
  select count(*) into v_reactions from public.reactions r
    join public.profiles p on p.id=r.user_id and p.status='active'
    where r.take_id=p_take_id and r.user_id<>v_take.user_id
      and not public.is_blocked(r.user_id,v_take.user_id);
  select count(distinct c.user_id) into v_commenters from public.comments c
    join public.profiles p on p.id=c.user_id and p.status='active'
    where c.take_id=p_take_id and c.status='active' and c.user_id<>v_take.user_id
      and not public.is_blocked(c.user_id,v_take.user_id);

  v_score := case when v_take.status<>'published' or v_impressions<5 then 0 else
    round((((40.0*least(v_reactions::numeric/v_impressions,1)) +
      (35.0*least(v_commenters::numeric/v_impressions,1)) +
      (25.0*(v_completed::numeric/v_impressions))) *
      least(1,ln(1+v_impressions)/ln(51)))::numeric,4)
  end;

  insert into public.take_metrics(
    take_id,impressions,completed_views,unique_viewers,reaction_count,
    unique_commenters,comment_count,ranking_score,updated_at
  ) values(
    p_take_id,v_impressions,v_completed,v_impressions,v_reactions,
    v_commenters,(select count(*) from public.comments where take_id=p_take_id and status='active'),v_score,now()
  ) on conflict(take_id) do update set
    impressions=excluded.impressions,completed_views=excluded.completed_views,
    unique_viewers=excluded.unique_viewers,reaction_count=excluded.reaction_count,
    unique_commenters=excluded.unique_commenters,comment_count=excluded.comment_count,
    ranking_score=excluded.ranking_score,updated_at=now();

  delete from public.daily_rankings where challenge_id=v_take.challenge_id;
  insert into public.daily_rankings(challenge_id,scope,country_code,user_id,take_id,rank,score)
  select t.challenge_id,'world','',t.user_id,t.id,
    dense_rank() over(order by m.ranking_score desc,t.created_at asc),m.ranking_score
  from public.takes t join public.take_metrics m on m.take_id=t.id
  where t.challenge_id=v_take.challenge_id and t.status='published';
  insert into public.daily_rankings(challenge_id,scope,country_code,user_id,take_id,rank,score)
  select t.challenge_id,'country',p.country_code,t.user_id,t.id,
    dense_rank() over(partition by p.country_code order by m.ranking_score desc,t.created_at asc),m.ranking_score
  from public.takes t join public.take_metrics m on m.take_id=t.id
  join public.profiles p on p.id=t.user_id
  where t.challenge_id=v_take.challenge_id and t.status='published';

  delete from public.all_time_rankings where true;
  insert into public.all_time_rankings(scope,country_code,user_id,rank,score)
  select 'world','',t.user_id,dense_rank() over(order by sum(m.ranking_score+2) desc),sum(m.ranking_score+2)
  from public.takes t join public.take_metrics m on m.take_id=t.id
  where t.status='published' group by t.user_id;
  insert into public.all_time_rankings(scope,country_code,user_id,rank,score)
  select 'country',p.country_code,t.user_id,
    dense_rank() over(partition by p.country_code order by sum(m.ranking_score+2) desc),sum(m.ranking_score+2)
  from public.takes t join public.take_metrics m on m.take_id=t.id
  join public.profiles p on p.id=t.user_id
  where t.status='published' group by p.country_code,t.user_id;
end;
$$;

create or replace function public.reconcile_today_participation()
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_challenge public.challenges%rowtype;
  v_attempt public.take_attempts%rowtype;
  v_take public.takes%rowtype;
  v_object_name text;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select * into v_challenge from public.challenges c
    where c.publish_at<=now() and c.expires_at>now()
      and c.status in ('active','scheduled') order by c.publish_at desc limit 1;
  if not found then return false; end if;

  select a.* into v_attempt from public.take_attempts a
    where a.user_id=v_user and a.challenge_id=v_challenge.id
    order by a.attempt_number desc limit 1 for update;
  select * into v_take from public.takes t
    where t.user_id=v_user and t.challenge_id=v_challenge.id
    order by t.created_at desc limit 1 for update;

  if v_take.id is not null and v_take.storage_path is null then
    select o.name into v_object_name from storage.objects o
      where o.bucket_id='takes'
        and o.name=v_user::text||'/'||v_take.attempt_id::text||'/'||v_take.id::text||'/video.mp4'
      limit 1;
    if v_object_name is not null then
      update public.takes set storage_path=v_object_name,status='processing'
        where id=v_take.id and storage_path is null;
      update public.take_attempts set status='finalized',finalized_at=coalesce(finalized_at,now())
        where id=v_take.attempt_id and status<>'finalized';
      insert into public.take_metrics(take_id) values(v_take.id) on conflict do nothing;
      insert into public.moderation_queue(target_type,target_id,source,priority)
        select 'take',v_take.id,'automated',60
        where not exists(select 1 from public.moderation_queue where target_type='take' and target_id=v_take.id);
      v_take.storage_path := v_object_name;
      v_take.status := 'processing';
      v_attempt.id := v_take.attempt_id;
    end if;
  end if;

  if v_take.id is not null and v_take.storage_path is not null then
    insert into public.challenge_participations(
      user_id,challenge_id,attempt_id,take_id,status,recorded_at,submitted_at,completed_at,error_code
    ) values(
      v_user,v_challenge.id,v_take.attempt_id,v_take.id,'completed',
      coalesce(v_attempt.started_at,v_take.created_at),v_take.created_at,now(),null
    ) on conflict(user_id,challenge_id) do update set
      attempt_id=excluded.attempt_id,take_id=excluded.take_id,status='completed',
      recorded_at=coalesce(public.challenge_participations.recorded_at,excluded.recorded_at),
      submitted_at=coalesce(public.challenge_participations.submitted_at,excluded.submitted_at),
      completed_at=coalesce(public.challenge_participations.completed_at,excluded.completed_at),
      error_code=null,updated_at=now();
    return true;
  end if;

  if v_take.id is not null then
    insert into public.challenge_participations(user_id,challenge_id,attempt_id,take_id,status,recorded_at)
    values(v_user,v_challenge.id,v_take.attempt_id,v_take.id,'uploading',v_attempt.started_at)
    on conflict(user_id,challenge_id) do update set
      attempt_id=excluded.attempt_id,take_id=excluded.take_id,status='uploading',updated_at=now();
  elsif v_attempt.id is not null then
    insert into public.challenge_participations(user_id,challenge_id,attempt_id,status,recorded_at,error_code)
    values(v_user,v_challenge.id,v_attempt.id,
      case when v_attempt.status in ('technical_failure','expired') then 'failed_technical'
           when v_attempt.status='started' then 'recorded' else 'attempt_started' end,
      v_attempt.started_at,
      case when v_attempt.status in ('technical_failure','expired') then coalesce(v_attempt.retry_reason,'attempt_expired_without_upload') else null end)
    on conflict(user_id,challenge_id) do update set
      attempt_id=excluded.attempt_id,status=excluded.status,recorded_at=excluded.recorded_at,
      error_code=excluded.error_code,updated_at=now();
  end if;
  return false;
end;
$$;

create or replace function public.has_valid_take_today()
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform public.reconcile_today_participation();
  return exists(
    select 1 from public.challenge_participations p
    join public.challenges c on c.id=p.challenge_id
    where p.user_id=auth.uid() and p.status in ('submitted','processing','completed')
      and c.publish_at<=now() and c.expires_at>now()
  );
end;
$$;

create or replace function public.reserve_take_upload(
  p_attempt_id uuid,p_nonce uuid,p_duration_ms integer,p_file_size integer,p_look text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_attempt public.take_attempts%rowtype;
  v_take uuid;
  v_reserved_bytes bigint;
  v_budget_bytes constant bigint := 805306368;
begin
  select a.* into v_attempt from public.take_attempts a
    join public.challenges c on c.id=a.challenge_id
    where a.id=p_attempt_id and a.user_id=auth.uid() and a.nonce=p_nonce
      and c.publish_at<=now() and c.expires_at>now()
    for update of a;
  if not found or v_attempt.status not in ('started','upload_reserved','technical_failure','expired') then
    raise exception 'invalid_attempt';
  end if;
  if p_duration_ms not between 6800 and 7600 then raise exception 'invalid_duration'; end if;
  if p_file_size not between 1 and 12582912 then raise exception 'invalid_file_size'; end if;

  if not exists(select 1 from public.takes where user_id=auth.uid() and challenge_id=v_attempt.challenge_id) then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('svnly_free_tier_storage_budget'));
    select coalesce(sum(t.file_size),0) into v_reserved_bytes from public.takes t
      where t.status<>'deleted' and (t.storage_path is not null or t.created_at>now()-interval '1 day');
    if v_reserved_bytes+p_file_size>v_budget_bytes then raise exception 'free_tier_storage_budget_exceeded'; end if;
  end if;

  insert into public.takes(user_id,challenge_id,attempt_id,duration_ms,file_size,live_look)
  values(auth.uid(),v_attempt.challenge_id,p_attempt_id,p_duration_ms,p_file_size,p_look)
  on conflict(attempt_id) do update set
    duration_ms=excluded.duration_ms,file_size=excluded.file_size,live_look=excluded.live_look
  returning id into v_take;
  update public.take_attempts set status='upload_reserved',expires_at=greatest(expires_at,now()+interval '10 minutes')
    where id=p_attempt_id and status<>'finalized';
  insert into public.challenge_participations(user_id,challenge_id,attempt_id,take_id,status,recorded_at)
  values(auth.uid(),v_attempt.challenge_id,p_attempt_id,v_take,'uploading',v_attempt.started_at)
  on conflict(user_id,challenge_id) do update set
    attempt_id=excluded.attempt_id,take_id=excluded.take_id,status='uploading',error_code=null,updated_at=now();
  return v_take;
end;
$$;

create or replace function public.finalize_take(
  p_take_id uuid,p_attempt_id uuid,p_storage_path text,p_duration_ms integer,p_file_size integer
) returns void language plpgsql security definer set search_path = '' as $$
declare v_take public.takes%rowtype;
begin
  select * into v_take from public.takes
    where id=p_take_id and attempt_id=p_attempt_id and user_id=auth.uid() for update;
  if not found then raise exception 'take_not_found'; end if;
  if split_part(p_storage_path,'/',1)<>auth.uid()::text or right(lower(p_storage_path),4)<>'.mp4'
     or p_storage_path<>auth.uid()::text||'/'||p_attempt_id::text||'/'||p_take_id::text||'/video.mp4' then
    raise exception 'invalid_storage_path';
  end if;
  if p_duration_ms not between 6800 and 7600 or p_file_size not between 1 and 12582912 then
    raise exception 'invalid_media';
  end if;
  if not exists(select 1 from storage.objects where bucket_id='takes' and name=p_storage_path) then
    raise exception 'uploaded_object_not_found';
  end if;
  if v_take.storage_path is not null and v_take.storage_path<>p_storage_path then
    raise exception 'take_already_finalized';
  end if;

  update public.takes set storage_path=p_storage_path,status='processing' where id=p_take_id;
  update public.take_attempts set status='finalized',finalized_at=coalesce(finalized_at,now()) where id=p_attempt_id;
  insert into public.take_metrics(take_id) values(p_take_id) on conflict do nothing;
  insert into public.moderation_queue(target_type,target_id,source,priority)
    select 'take',p_take_id,'automated',60
    where not exists(select 1 from public.moderation_queue where target_type='take' and target_id=p_take_id);
  insert into public.challenge_participations(
    user_id,challenge_id,attempt_id,take_id,status,recorded_at,submitted_at,completed_at,error_code
  ) values(
    auth.uid(),v_take.challenge_id,p_attempt_id,p_take_id,'completed',
    (select started_at from public.take_attempts where id=p_attempt_id),now(),now(),null
  ) on conflict(user_id,challenge_id) do update set
    attempt_id=excluded.attempt_id,take_id=excluded.take_id,status='completed',
    recorded_at=coalesce(public.challenge_participations.recorded_at,excluded.recorded_at),
    submitted_at=coalesce(public.challenge_participations.submitted_at,excluded.submitted_at),
    completed_at=coalesce(public.challenge_participations.completed_at,excluded.completed_at),
    error_code=null,updated_at=now();
  insert into public.analytics_events(user_id,event_name,properties)
    values(auth.uid(),'upload_completed',jsonb_build_object('duration_ms',p_duration_ms,'size_bucket_kb',(p_file_size/1024/256)*256));
end;
$$;

create or replace function public.request_technical_retry(
  p_attempt_id uuid,p_reason text,p_diagnostics jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path = '' as $$
declare v_attempt public.take_attempts%rowtype;
begin
  if p_reason not in ('camera_initialization_failed','camera_or_recording_error','duration_out_of_tolerance','app_backgrounded','file_corrupt','upload_failed','server_rejected_technical') then
    raise exception 'invalid_retry_reason';
  end if;
  perform public.reconcile_today_participation();
  select * into v_attempt from public.take_attempts where id=p_attempt_id and user_id=auth.uid() for update;
  if not found or v_attempt.status not in ('issued','started','upload_reserved','expired','technical_failure') then
    raise exception 'retry_not_available';
  end if;
  if v_attempt.retry_count>=2 then raise exception 'retry_limit_reached'; end if;
  if exists(select 1 from public.takes where attempt_id=p_attempt_id and storage_path is not null) then
    raise exception 'recorded_file_exists';
  end if;
  delete from public.takes where attempt_id=p_attempt_id and storage_path is null;
  update public.take_attempts set status='technical_failure',technical_retry_granted=true,
    retry_reason=p_reason,diagnostics=jsonb_build_object('reason',p_reason,'elapsed_ms',p_diagnostics->'elapsed_ms','app_state',p_diagnostics->'app_state','recorded_at',now())
    where id=p_attempt_id;
  update public.challenge_participations set status='failed_technical',take_id=null,error_code=p_reason,updated_at=now()
    where user_id=auth.uid() and challenge_id=v_attempt.challenge_id;
  insert into public.analytics_events(user_id,event_name,properties)
    values(auth.uid(),'technical_retry',jsonb_build_object('reason',p_reason));
end;
$$;

-- Expired attempts with no server-side take are verified technical failures and
-- may produce the next attempt without manual intervention.
create or replace function public.issue_take_attempt()
returns table(attempt_id uuid,nonce uuid,expires_at timestamptz,retry_count smallint)
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid:=auth.uid(); v_challenge uuid; v_attempt public.take_attempts%rowtype; v_count integer;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select c.id into v_challenge from public.challenges c where c.publish_at<=now() and c.expires_at>now()
    and c.status in ('active','scheduled') order by c.publish_at desc limit 1;
  if v_challenge is null then raise exception 'no_active_challenge'; end if;
  if not exists(select 1 from public.profiles p join public.user_private u on u.user_id=p.id
    where p.id=v_user and p.status='active' and u.age_verified_at is not null
      and exists(select 1 from public.terms_acceptances a where a.user_id=v_user and a.document_type='terms')
      and exists(select 1 from public.terms_acceptances a where a.user_id=v_user and a.document_type='privacy')
      and exists(select 1 from public.terms_acceptances a where a.user_id=v_user and a.document_type='guidelines')) then
    raise exception 'profile_not_eligible';
  end if;
  perform public.reconcile_today_participation();
  if exists(select 1 from public.challenge_participations where user_id=v_user and challenge_id=v_challenge and status in ('submitted','processing','completed')) then
    raise exception 'take_already_exists';
  end if;
  select * into v_attempt from public.take_attempts where user_id=v_user and challenge_id=v_challenge
    order by attempt_number desc limit 1 for update;
  if found and v_attempt.status='expired' and not exists(select 1 from public.takes t where t.attempt_id=v_attempt.id) then
    update public.take_attempts set status='technical_failure',technical_retry_granted=true,
      retry_reason='attempt_expired_without_upload' where id=v_attempt.id;
    v_attempt.status:='technical_failure'; v_attempt.technical_retry_granted:=true;
  end if;
  if found and v_attempt.status='issued' and v_attempt.expires_at>now() then raise exception 'attempt_already_active'; end if;
  if found and v_attempt.status in ('started','upload_reserved','finalized') then raise exception 'attempt_consumed'; end if;
  if found and not v_attempt.technical_retry_granted then raise exception 'technical_retry_not_granted'; end if;
  select count(*) into v_count from public.take_attempts where user_id=v_user and challenge_id=v_challenge;
  if v_count>=3 then raise exception 'retry_limit_reached'; end if;
  insert into public.take_attempts(user_id,challenge_id,attempt_number,retry_count)
  values(v_user,v_challenge,v_count+1,greatest(v_count,0))
  returning id,public.take_attempts.nonce,public.take_attempts.expires_at,public.take_attempts.retry_count
  into attempt_id,nonce,expires_at,retry_count;
  insert into public.challenge_participations(user_id,challenge_id,attempt_id,status,error_code)
  values(v_user,v_challenge,attempt_id,'attempt_started',null)
  on conflict(user_id,challenge_id) do update set attempt_id=excluded.attempt_id,take_id=null,status='attempt_started',error_code=null,updated_at=now();
  return next;
end;
$$;

-- Backfill authoritative participation without letting moderation status alter it.
insert into public.challenge_participations(
  user_id,challenge_id,attempt_id,take_id,status,recorded_at,submitted_at,completed_at
)
select t.user_id,t.challenge_id,t.attempt_id,t.id,'completed',a.started_at,t.created_at,coalesce(a.finalized_at,t.updated_at)
from public.takes t join public.take_attempts a on a.id=t.attempt_id
where t.storage_path is not null
on conflict(user_id,challenge_id) do update set
  attempt_id=excluded.attempt_id,take_id=excluded.take_id,status='completed',
  recorded_at=excluded.recorded_at,submitted_at=excluded.submitted_at,completed_at=excluded.completed_at,updated_at=now();

revoke all on function public.reconcile_today_participation(),public.has_valid_take_today(),
  public.reserve_take_upload(uuid,uuid,integer,integer,text),
  public.finalize_take(uuid,uuid,text,integer,integer),
  public.request_technical_retry(uuid,text,jsonb),public.issue_take_attempt()
  from public,anon;
grant execute on function public.reconcile_today_participation(),public.has_valid_take_today(),
  public.reserve_take_upload(uuid,uuid,integer,integer,text),
  public.finalize_take(uuid,uuid,text,integer,integer),
  public.request_technical_retry(uuid,text,jsonb),public.issue_take_attempt()
  to authenticated;

commit;
