begin;

create or replace function public.can_access_take(p_take_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(
    select 1
    from public.takes t
    join public.profiles owner on owner.id=t.user_id
    where t.id=p_take_id and (
      t.user_id=auth.uid()
      or (
        t.status='published'
        and not public.is_blocked(auth.uid(),t.user_id)
        and (
          not owner.is_private
          or exists(
            select 1 from public.follows f
            where f.follower_id=auth.uid() and f.followed_id=t.user_id and f.status='accepted'
          )
        )
        and exists(
          select 1
          from public.challenge_participations cp
          join public.challenges c on c.id=cp.challenge_id
          where cp.user_id=auth.uid()
            and cp.status in ('submitted','processing','completed')
            and c.publish_at<=now() and c.expires_at>now()
        )
      )
    )
  );
$$;

create or replace function public.set_reaction(p_take_id uuid,p_reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select user_id into v_owner from public.takes
    where id=p_take_id and status='published' and public.can_access_take(id);
  if v_owner is null or v_owner=auth.uid() then raise exception 'reaction_not_allowed'; end if;
  if p_reaction is null then
    delete from public.reactions where user_id=auth.uid() and take_id=p_take_id;
  elsif p_reaction in ('heart','laugh','fire','wow') then
    insert into public.reactions(user_id,take_id,reaction)
    values(auth.uid(),p_take_id,p_reaction)
    on conflict(user_id,take_id) do update set reaction=excluded.reaction,updated_at=now();
  else
    raise exception 'invalid_reaction';
  end if;
  update public.take_metrics set
    reaction_count=(select count(*) from public.reactions where take_id=p_take_id),updated_at=now()
  where take_id=p_take_id;
end;
$$;

create or replace function public.create_comment(p_take_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_owner uuid; v_permission public.comment_permission; v_id uuid;
begin
  if char_length(trim(p_body)) not between 1 and 280 or p_body ~ '<[^>]*>' then
    raise exception 'invalid_comment';
  end if;
  if (select count(*) from public.comments where user_id=auth.uid() and created_at>now()-interval '1 minute')>=5 then
    raise exception 'comment_rate_limit';
  end if;
  select t.user_id,p.comment_permission into v_owner,v_permission
  from public.takes t join public.profiles p on p.id=t.user_id
  where t.id=p_take_id and t.status='published' and public.can_access_take(t.id);
  if v_owner is null or v_permission='disabled' then raise exception 'comments_disabled'; end if;
  if v_permission='followers' and v_owner<>auth.uid() and not exists(
    select 1 from public.follows
    where follower_id=auth.uid() and followed_id=v_owner and status='accepted'
  ) then raise exception 'followers_only'; end if;
  insert into public.comments(user_id,take_id,body)
  values(auth.uid(),p_take_id,trim(p_body)) returning id into v_id;
  update public.take_metrics set
    comment_count=(select count(*) from public.comments where take_id=p_take_id and status='active'),
    unique_commenters=(select count(distinct user_id) from public.comments where take_id=p_take_id and status='active')
  where take_id=p_take_id;
  return v_id;
end;
$$;

create or replace function public.get_comments(
  p_take_id uuid,p_limit integer default 30,p_offset integer default 0
) returns table(
  id uuid,profile_id uuid,username text,body text,created_at timestamptz,is_mine boolean
) language sql stable security definer set search_path = '' as $$
  select c.id,p.id,p.username::text,c.body,c.created_at,c.user_id=auth.uid()
  from public.comments c join public.profiles p on p.id=c.user_id
  where c.take_id=p_take_id and c.status='active'
    and public.can_access_take(p_take_id)
    and not public.is_blocked(auth.uid(),c.user_id)
  order by c.created_at desc
  limit least(greatest(p_limit,1),50) offset greatest(p_offset,0);
$$;

revoke all on function public.can_access_take(uuid),public.set_reaction(uuid,text),
  public.create_comment(uuid,text),public.get_comments(uuid,integer,integer)
  from public,anon;
grant execute on function public.set_reaction(uuid,text),public.create_comment(uuid,text),
  public.get_comments(uuid,integer,integer) to authenticated;

commit;
