-- Idempotent database jobs. External calls use Vault secrets named
-- project_url and cron_secret; no credential is stored in migration SQL.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

create or replace function public.run_scheduler_tick(p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_expired integer; v_activated integer; v_attempts integer; v_notifications integer;
begin
  update public.challenges set status='expired',updated_at=p_now
    where status in ('active','scheduled') and expires_at<=p_now;
  get diagnostics v_expired=row_count;
  update public.challenges set status='active',updated_at=p_now
    where status='scheduled' and publish_at<=p_now and expires_at>p_now;
  get diagnostics v_activated=row_count;
  update public.take_attempts set status='expired'
    where status in ('issued','started','upload_reserved') and expires_at<=p_now;
  get diagnostics v_attempts=row_count;

  insert into public.notifications(user_id,category,title_key,body_key,data,dedupe_key)
  select p.id,'daily_challenge','daily_challenge_title','daily_challenge_body',
    jsonb_build_object('challenge_id',c.id,'challenge_date',c.challenge_date),
    'daily:'||c.challenge_date::text||':'||p.id
  from public.challenges c cross join public.profiles p
  join public.notification_preferences np on np.user_id=p.id and np.daily_challenge_push
  where c.status='active' and c.publish_at<=p_now and c.expires_at>p_now and p.status='active'
  on conflict(dedupe_key) do nothing;
  get diagnostics v_notifications=row_count;
  return jsonb_build_object('expired_challenges',v_expired,'activated_challenges',v_activated,
    'expired_attempts',v_attempts,'daily_notifications',v_notifications);
end;
$$;

create or replace function public.enqueue_streak_reminders(p_now timestamptz default now())
returns integer language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  insert into public.notifications(user_id,category,title_key,body_key,data,dedupe_key)
  select p.id,'streak','streak_title','streak_body',jsonb_build_object('challenge_id',c.id),
    'streak:'||c.challenge_date::text||':'||p.id
  from public.profiles p
  join public.user_settings us on us.user_id=p.id
  join public.notification_preferences np on np.user_id=p.id and np.streak_push
  join pg_catalog.pg_timezone_names tz on tz.name=us.timezone
  cross join lateral (
    select id,challenge_date from public.challenges
    where status='active' and publish_at<=p_now and expires_at>p_now limit 1
  ) c
  where p.status='active' and p.current_streak>0
    and extract(hour from p_now at time zone tz.name)=20
    and not exists(select 1 from public.takes t where t.user_id=p.id and t.challenge_id=c.id
      and t.status in ('processing','published','under_review'))
  on conflict(dedupe_key) do nothing;
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;

create or replace function public.refresh_all_streaks()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_user record; v_count integer:=0;
begin
  for v_user in select id from public.profiles where status='active' loop
    perform public.refresh_user_streak(v_user.id);
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.refresh_all_rankings()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  insert into public.take_metrics(take_id,impressions,completed_views,unique_viewers,reaction_count,
    unique_commenters,comment_count,ranking_score,updated_at)
  select t.id,
    coalesce(v.impressions,0),coalesce(v.completed,0),coalesce(v.impressions,0),
    coalesce(r.reaction_count,0),coalesce(cm.unique_commenters,0),coalesce(cm.comment_count,0),
    case when t.status<>'published' or coalesce(v.impressions,0)<5 then 0 else round(((
      40.0*least(coalesce(r.reaction_count,0)::numeric/v.impressions,1)+
      35.0*least(coalesce(cm.unique_commenters,0)::numeric/v.impressions,1)+
      25.0*(coalesce(v.completed,0)::numeric/v.impressions)
    )*least(1,ln(1+v.impressions)/ln(51)))::numeric,4) end,now()
  from public.takes t
  left join lateral (select count(*)::integer impressions,
    count(*) filter(where tv.completed)::integer completed from public.take_views tv where tv.take_id=t.id) v on true
  left join lateral (select count(*)::integer reaction_count from public.reactions rx
    join public.profiles rp on rp.id=rx.user_id and rp.status='active'
    where rx.take_id=t.id and rx.user_id<>t.user_id and not public.is_blocked(rx.user_id,t.user_id)) r on true
  left join lateral (select count(distinct cc.user_id)::integer unique_commenters,count(*)::integer comment_count
    from public.comments cc join public.profiles cp on cp.id=cc.user_id and cp.status='active'
    where cc.take_id=t.id and cc.status='active' and cc.user_id<>t.user_id
      and not public.is_blocked(cc.user_id,t.user_id)) cm on true
  on conflict(take_id) do update set impressions=excluded.impressions,
    completed_views=excluded.completed_views,unique_viewers=excluded.unique_viewers,
    reaction_count=excluded.reaction_count,unique_commenters=excluded.unique_commenters,
    comment_count=excluded.comment_count,ranking_score=excluded.ranking_score,updated_at=now();
  get diagnostics v_count=row_count;

  delete from public.daily_rankings;
  insert into public.daily_rankings(challenge_id,scope,country_code,user_id,take_id,rank,score)
  select t.challenge_id,'world','',t.user_id,t.id,
    dense_rank() over(partition by t.challenge_id order by m.ranking_score desc,t.created_at),m.ranking_score
  from public.takes t join public.take_metrics m on m.take_id=t.id where t.status='published';
  insert into public.daily_rankings(challenge_id,scope,country_code,user_id,take_id,rank,score)
  select t.challenge_id,'country',p.country_code,t.user_id,t.id,
    dense_rank() over(partition by t.challenge_id,p.country_code order by m.ranking_score desc,t.created_at),m.ranking_score
  from public.takes t join public.take_metrics m on m.take_id=t.id
  join public.profiles p on p.id=t.user_id where t.status='published';

  delete from public.all_time_rankings;
  insert into public.all_time_rankings(scope,country_code,user_id,rank,score)
  select 'world','',scores.user_id,dense_rank() over(order by scores.score desc),scores.score
  from (select t.user_id,sum(m.ranking_score+2) score from public.takes t
    join public.take_metrics m on m.take_id=t.id where t.status='published' group by t.user_id) scores;
  insert into public.all_time_rankings(scope,country_code,user_id,rank,score)
  select 'country',scores.country_code,scores.user_id,
    dense_rank() over(partition by scores.country_code order by scores.score desc),scores.score
  from (select p.country_code,t.user_id,sum(m.ranking_score+2) score from public.takes t
    join public.take_metrics m on m.take_id=t.id join public.profiles p on p.id=t.user_id
    where t.status='published' group by p.country_code,t.user_id) scores;
  update public.profiles p set best_rank=r.best_rank,updated_at=now()
  from (select user_id,min(rank) best_rank from public.daily_rankings where scope='world' group by user_id) r
  where p.id=r.user_id and (p.best_rank is null or r.best_rank<p.best_rank);
  return v_count;
end;
$$;

create or replace function public.run_database_cleanup(p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_attempts integer; v_notifications integer; v_tokens integer; v_events integer;
begin
  delete from public.take_attempts a where a.status in ('expired','technical_failure')
    and a.issued_at<p_now-interval '30 days'
    and not exists(select 1 from public.takes t where t.attempt_id=a.id);
  get diagnostics v_attempts=row_count;
  delete from public.notifications where created_at<p_now-interval '90 days'
    and delivery_status in ('sent','failed','no_device');
  get diagnostics v_notifications=row_count;
  delete from public.device_tokens where invalidated_at<p_now-interval '30 days'
    or (last_seen_at<p_now-interval '180 days' and invalidated_at is not null);
  get diagnostics v_tokens=row_count;
  delete from public.analytics_events where occurred_at<p_now-interval '180 days';
  get diagnostics v_events=row_count;
  return jsonb_build_object('attempts',v_attempts,'notifications',v_notifications,
    'device_tokens',v_tokens,'analytics_events',v_events);
end;
$$;

create or replace function public.invoke_scheduled_edge_job()
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text; v_request_id bigint;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name='project_url' limit 1;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name='cron_secret' limit 1;
  if v_url is null or v_secret is null then return null; end if;
  select net.http_post(url=rtrim(v_url,'/')||'/functions/v1/scheduled-jobs',
    headers=jsonb_build_object('Content-Type','application/json','x-cron-secret',v_secret),
    body='{}'::jsonb,timeout_milliseconds=55000) into v_request_id;
  return v_request_id;
end;
$$;

select cron.schedule('svnly-lifecycle','*/5 * * * *','select public.run_scheduler_tick();');
select cron.schedule('svnly-streak-reminders','7 * * * *','select public.enqueue_streak_reminders();');
select cron.schedule('svnly-ranking','*/15 * * * *','select public.refresh_all_rankings();');
select cron.schedule('svnly-streak-refresh','17 0 * * *','select public.refresh_all_streaks();');
select cron.schedule('svnly-cleanup','23 3 * * *','select public.run_database_cleanup();');
select cron.schedule('svnly-edge-orchestrator','*/2 * * * *','select public.invoke_scheduled_edge_job();');

revoke all on function public.run_scheduler_tick(timestamptz),public.enqueue_streak_reminders(timestamptz),
  public.refresh_all_streaks(),public.refresh_all_rankings(),public.run_database_cleanup(timestamptz),
  public.invoke_scheduled_edge_job() from public,anon,authenticated;
grant execute on function public.run_scheduler_tick(timestamptz),public.enqueue_streak_reminders(timestamptz),
  public.refresh_all_streaks(),public.refresh_all_rankings(),public.run_database_cleanup(timestamptz),
  public.invoke_scheduled_edge_job() to service_role;
