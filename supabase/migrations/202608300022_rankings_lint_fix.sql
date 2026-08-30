begin;

-- Output columns of a PL/pgSQL table function are variables. Qualify every
-- profile reference so PostgreSQL cannot confuse the output country_code with
-- the source column when the function executes in production.
create or replace function public.get_rankings(
  p_period text,
  p_scope text,
  p_limit integer default 100
)
returns table(
  rank integer,
  user_id uuid,
  username text,
  display_name text,
  country_code text,
  score numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_country text;
  v_challenge uuid;
begin
  select profile.country_code into v_country
  from public.profiles as profile
  where profile.id=auth.uid();

  select challenge.id into v_challenge
  from public.challenges as challenge
  where challenge.publish_at<=now() and challenge.expires_at>now()
  order by challenge.publish_at desc
  limit 1;

  if p_period='today' then
    return query
    select r.rank,r.user_id,p.username::text,p.display_name,p.country_code,r.score
    from public.daily_rankings as r
    join public.profiles as p on p.id=r.user_id
    where r.challenge_id=v_challenge
      and r.scope=case when p_scope='country' then 'country' else 'world' end
      and (p_scope<>'country' or r.country_code=v_country)
      and (p_scope<>'friends' or exists(
        select 1 from public.follows as f
        where f.follower_id=auth.uid()
          and f.followed_id=r.user_id
          and f.status='accepted'
      ))
      and not public.is_blocked(auth.uid(),r.user_id)
    order by r.rank
    limit least(p_limit,100);
  elsif p_period='all_time' then
    return query
    select r.rank,r.user_id,p.username::text,p.display_name,p.country_code,r.score
    from public.all_time_rankings as r
    join public.profiles as p on p.id=r.user_id
    where r.scope=case when p_scope='country' then 'country' else 'world' end
      and (p_scope<>'country' or r.country_code=v_country)
      and (p_scope<>'friends' or exists(
        select 1 from public.follows as f
        where f.follower_id=auth.uid()
          and f.followed_id=r.user_id
          and f.status='accepted'
      ))
      and not public.is_blocked(auth.uid(),r.user_id)
    order by r.rank
    limit least(p_limit,100);
  else
    raise exception 'invalid_period';
  end if;
end;
$$;

commit;
