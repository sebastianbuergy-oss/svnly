begin;

-- Keep the Build 11 JSON keys and value shapes while adding avatar_path. The
-- final client reads My Take through get_my_takes, but the currently installed
-- device build must continue rendering its published history until replaced.
create or replace function public.get_my_profile()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id',p.id,'username',p.username,'display_name',p.display_name,'country_code',p.country_code,
    'avatar_path',p.avatar_path,'bio',p.bio,'total_takes',p.total_takes,
    'followers_count',p.followers_count,'following_count',p.following_count,
    'current_streak',p.current_streak,'longest_streak',p.longest_streak,'best_rank',p.best_rank,
    'badges',coalesce((
      select jsonb_agg(b.name_en order by ub.awarded_at)
      from public.user_badges ub join public.badges b on b.id=ub.badge_id where ub.user_id=p.id
    ),'[]'::jsonb),
    'take_history',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',t.id,'challenge_title',c.title_en,'challenge_date',c.challenge_date,'rank',r.rank
      ) order by c.challenge_date desc)
      from public.takes t
      join public.challenges c on c.id=t.challenge_id
      left join public.daily_rankings r
        on r.take_id=t.id and r.scope='world' and r.country_code=''
      where t.user_id=p.id and t.status='published'
    ),'[]'::jsonb)
  ) from public.profiles p where p.id=auth.uid();
$$;

revoke all on function public.get_my_profile() from public,anon;
grant execute on function public.get_my_profile() to authenticated;

commit;
