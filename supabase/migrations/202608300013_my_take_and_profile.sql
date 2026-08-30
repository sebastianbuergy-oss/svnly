begin;

-- Streaks and total takes follow the immutable participation receipt, not a
-- moderation status that can change later.
create or replace function public.refresh_user_streak(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_current integer:=0;
  v_longest integer:=0;
  v_last date;
begin
  with participation_dates as (
    select distinct c.challenge_date
    from public.challenge_participations cp
    join public.challenges c on c.id=cp.challenge_id
    where cp.user_id=p_user_id and cp.status in ('submitted','processing','completed')
  ), grouped as (
    select challenge_date,
      challenge_date-row_number() over(order by challenge_date)::integer as island
    from participation_dates
  ), streaks as (
    select island,count(*)::integer as length,max(challenge_date) as last_date
    from grouped group by island
  )
  select coalesce(max(length),0),max(last_date),
    coalesce(max(length) filter(where last_date>=current_date-1),0)
  into v_longest,v_last,v_current from streaks;

  update public.profiles set
    current_streak=v_current,
    longest_streak=greatest(longest_streak,v_longest),
    last_completed_challenge_date=v_last,
    total_takes=(select count(*) from public.challenge_participations
      where user_id=p_user_id and status in ('submitted','processing','completed')),
    updated_at=now()
  where id=p_user_id;

  insert into public.user_badges(user_id,badge_id)
  select p_user_id,b.id from public.badges b
  where (b.id='first_take' and exists(
      select 1 from public.challenge_participations
      where user_id=p_user_id and status in ('submitted','processing','completed')
    ))
    or (b.id='streak_7' and v_longest>=7)
    or (b.id='streak_30' and v_longest>=30)
    or (b.id='streak_100' and v_longest>=100)
  on conflict do nothing;
end;
$$;

create or replace function public.participation_refresh_profile_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.refresh_user_streak(new.user_id);
  return new;
end;
$$;

drop trigger if exists challenge_participation_refresh_profile on public.challenge_participations;
create trigger challenge_participation_refresh_profile
after insert or update of status on public.challenge_participations
for each row execute function public.participation_refresh_profile_trigger();

select public.refresh_user_streak(p.id) from public.profiles p;

-- The owner view is deliberately independent from moderation visibility. A
-- submitted take remains visible to its creator while processing or under
-- review, and a later moderation decision never removes the participation
-- proof or the owner's history entry.
create or replace function public.get_my_takes(p_limit integer default 30)
returns table(
  id uuid,
  challenge_id uuid,
  challenge_title text,
  challenge_date date,
  storage_path text,
  thumbnail_path text,
  take_status text,
  participation_status text,
  reaction_count integer,
  comment_count integer,
  view_count integer,
  created_at timestamptz,
  is_today boolean
) language sql stable security definer set search_path = '' as $$
  select
    t.id,
    c.id,
    case when (select s.language_code from public.user_settings s where s.user_id=auth.uid())='de'
      then c.title_de else c.title_en end,
    c.challenge_date,
    t.storage_path,
    t.thumbnail_path,
    t.status::text,
    coalesce(cp.status, case when t.storage_path is null then 'uploading' else 'completed' end),
    coalesce(m.reaction_count,0),
    coalesce(m.comment_count,0),
    coalesce(m.impressions,0),
    t.created_at,
    c.publish_at<=now() and c.expires_at>now()
  from public.takes t
  join public.challenges c on c.id=t.challenge_id
  left join public.challenge_participations cp
    on cp.user_id=t.user_id and cp.challenge_id=t.challenge_id
  left join public.take_metrics m on m.take_id=t.id
  where t.user_id=auth.uid()

  union all

  select
    null::uuid,
    c.id,
    case when (select s.language_code from public.user_settings s where s.user_id=auth.uid())='de'
      then c.title_de else c.title_en end,
    c.challenge_date,
    null::text,
    null::text,
    null::text,
    cp.status,
    0,
    0,
    0,
    cp.created_at,
    c.publish_at<=now() and c.expires_at>now()
  from public.challenge_participations cp
  join public.challenges c on c.id=cp.challenge_id
  where cp.user_id=auth.uid() and cp.take_id is null
  order by challenge_date desc,created_at desc
  limit least(greatest(p_limit,1),100);
$$;

create or replace function public.update_my_profile(
  p_username text,
  p_display_name text,
  p_bio text,
  p_country_code text,
  p_avatar_path text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_profile public.profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if trim(p_username) !~ '^[A-Za-z0-9._]{3,20}$'
     or lower(trim(p_username)) ~ '(svnly|admin|moderator|support|official|security|help)' then
    raise exception 'invalid_username';
  end if;
  if char_length(trim(p_display_name)) not between 2 and 40 then
    raise exception 'invalid_display_name';
  end if;
  if char_length(trim(p_bio))>160 then raise exception 'invalid_bio'; end if;
  if p_country_code !~ '^[A-Z]{2}$' then raise exception 'invalid_country'; end if;
  if p_avatar_path is not null and p_avatar_path<>auth.uid()::text||'/avatar.jpg' then
    raise exception 'invalid_avatar_path';
  end if;
  if p_avatar_path is not null and not exists(
    select 1 from storage.objects o where o.bucket_id='avatars' and o.name=p_avatar_path
  ) then
    raise exception 'avatar_not_uploaded';
  end if;

  update public.profiles set
    username=trim(p_username)::public.citext,
    display_name=trim(p_display_name),
    bio=trim(p_bio),
    country_code=p_country_code,
    avatar_path=coalesce(p_avatar_path,avatar_path),
    country_changed_at=case when country_code is distinct from p_country_code then now() else country_changed_at end,
    updated_at=now()
  where id=auth.uid() and status='active'
  returning * into v_profile;
  if not found then raise exception 'profile_not_found'; end if;

  return jsonb_build_object(
    'id',v_profile.id,'username',v_profile.username,'display_name',v_profile.display_name,
    'bio',v_profile.bio,'country_code',v_profile.country_code,'avatar_path',v_profile.avatar_path
  );
exception when unique_violation then
  raise exception 'username_taken';
end;
$$;

create or replace function public.get_my_profile()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id',p.id,'username',p.username,'display_name',p.display_name,'country_code',p.country_code,
    'avatar_path',p.avatar_path,'bio',p.bio,'total_takes',p.total_takes,
    'followers_count',p.followers_count,'following_count',p.following_count,
    'current_streak',p.current_streak,'longest_streak',p.longest_streak,'best_rank',p.best_rank,
    'badges',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',b.id,'name',b.name_en,'description',b.description_en,'awarded_at',ub.awarded_at
      ) order by ub.awarded_at desc)
      from public.user_badges ub join public.badges b on b.id=ub.badge_id where ub.user_id=p.id
    ),'[]'::jsonb)
  ) from public.profiles p where p.id=auth.uid();
$$;

revoke all on function public.get_my_takes(integer),
  public.update_my_profile(text,text,text,text,text),public.get_my_profile(),
  public.refresh_user_streak(uuid),public.participation_refresh_profile_trigger()
  from public,anon;
grant execute on function public.get_my_takes(integer),
  public.update_my_profile(text,text,text,text,text),public.get_my_profile()
  to authenticated;

commit;
