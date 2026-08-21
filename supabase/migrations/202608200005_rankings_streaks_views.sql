-- Server-authoritative view metrics, normalized rankings, streaks and badges.

create table public.take_views (
  id uuid primary key default gen_random_uuid(),
  take_id uuid not null references public.takes(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  completed boolean not null default false,
  viewed_at timestamptz not null default now(),
  unique(take_id, viewer_id)
);

create index take_views_take_idx on public.take_views(take_id);
alter table public.take_views enable row level security;

create or replace function public.refresh_user_streak(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_current integer := 0;
  v_longest integer := 0;
  v_last date;
begin
  with participation_dates as (
    select distinct c.challenge_date
    from public.takes t
    join public.challenges c on c.id=t.challenge_id
    where t.user_id=p_user_id
      and t.status in ('published','under_review','deleted')
  ), grouped as (
    select challenge_date,
      challenge_date - row_number() over(order by challenge_date)::integer as island
    from participation_dates
  ), streaks as (
    select island,count(*)::integer as length,max(challenge_date) as last_date
    from grouped group by island
  )
  select coalesce(max(length),0),max(last_date),
    coalesce(max(length) filter(where last_date >= current_date-1),0)
  into v_longest,v_last,v_current from streaks;

  update public.profiles set
    current_streak=v_current,
    longest_streak=greatest(longest_streak,v_longest),
    last_completed_challenge_date=v_last,
    total_takes=(select count(distinct challenge_id) from public.takes
      where user_id=p_user_id and status in ('published','under_review','deleted')),
    updated_at=now()
  where id=p_user_id;

  insert into public.user_badges(user_id,badge_id)
  select p_user_id,b.id from public.badges b
  where (b.id='first_take' and exists(select 1 from public.takes where user_id=p_user_id and status='published'))
     or (b.id='streak_7' and v_longest>=7)
     or (b.id='streak_30' and v_longest>=30)
     or (b.id='streak_100' and v_longest>=100)
  on conflict do nothing;
end;
$$;

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
    round(((
      40.0*least(v_reactions::numeric/v_impressions,1) +
      35.0*least(v_commenters::numeric/v_impressions,1) +
      25.0*(v_completed::numeric/v_impressions)
    ) * least(1,ln(1+v_impressions)/ln(51)))::numeric,4)
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

  delete from public.all_time_rankings;
  insert into public.all_time_rankings(scope,country_code,user_id,rank,score)
  select 'world','',t.user_id,dense_rank() over(order by sum(m.ranking_score+2) desc),sum(m.ranking_score+2)
  from public.takes t join public.take_metrics m on m.take_id=t.id where t.status='published' group by t.user_id;
  insert into public.all_time_rankings(scope,country_code,user_id,rank,score)
  select 'country',p.country_code,t.user_id,
    dense_rank() over(partition by p.country_code order by sum(m.ranking_score+2) desc),sum(m.ranking_score+2)
  from public.takes t join public.take_metrics m on m.take_id=t.id
  join public.profiles p on p.id=t.user_id where t.status='published' group by p.country_code,t.user_id;
end;
$$;

create or replace function public.record_take_view(p_take_id uuid,p_completed boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select t.user_id into v_owner from public.takes t
  join public.profiles p on p.id=t.user_id and p.status='active'
  where t.id=p_take_id and t.status='published';
  if v_owner is null or v_owner=auth.uid() or public.is_blocked(auth.uid(),v_owner) then return; end if;
  insert into public.take_views(take_id,viewer_id,completed)
  values(p_take_id,auth.uid(),p_completed)
  on conflict(take_id,viewer_id) do update set completed=public.take_views.completed or excluded.completed;
  perform public.refresh_take_ranking(p_take_id);
end;
$$;

create or replace function public.takes_derived_state_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.refresh_user_streak(new.user_id);
  perform public.refresh_take_ranking(new.id);
  return new;
end;
$$;

create trigger takes_derived_state after insert or update of status on public.takes
for each row execute function public.takes_derived_state_trigger();

create or replace function public.interaction_ranking_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='DELETE' then
    perform public.refresh_take_ranking(old.take_id);
    return old;
  end if;
  perform public.refresh_take_ranking(new.take_id);
  return new;
end;
$$;

create trigger reactions_refresh_ranking after insert or update or delete on public.reactions
for each row execute function public.interaction_ranking_trigger();
create trigger comments_refresh_ranking after insert or update or delete on public.comments
for each row execute function public.interaction_ranking_trigger();

revoke all on table public.take_views from public,anon,authenticated;
revoke all on function public.refresh_user_streak(uuid),public.refresh_take_ranking(uuid),
  public.record_take_view(uuid,boolean),public.takes_derived_state_trigger(),
  public.interaction_ranking_trigger() from public,anon;
grant execute on function public.record_take_view(uuid,boolean) to authenticated;
