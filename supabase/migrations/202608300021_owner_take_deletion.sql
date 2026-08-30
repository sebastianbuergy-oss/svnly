begin;

-- Voluntary deletion removes the public/social object but never the immutable
-- daily participation receipt. Keeping both the take row and participation is
-- what prevents a cosmetic retake after the user has already submitted once.
create or replace function public.delete_my_take(p_take_id uuid)
returns table(
  take_id uuid,
  video_path text,
  thumbnail_path text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_take public.takes%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;

  select t.* into v_take
  from public.takes t
  where t.id=p_take_id and t.user_id=auth.uid()
  for update;
  if not found then raise exception 'take_not_owned'; end if;

  if v_take.status<>'deleted' then
    update public.takes as owned_take set
      status='deleted',
      deleted_at=coalesce(owned_take.deleted_at,now()),
      published_at=null,
      moderation_reason='user_deleted',
      updated_at=now()
    where owned_take.id=v_take.id;

    delete from public.reactions as r where r.take_id=v_take.id;
    delete from public.comments as c where c.take_id=v_take.id;
    delete from public.take_views as tv where tv.take_id=v_take.id;
    delete from public.notifications as n where n.data->>'take_id'=v_take.id::text;
    delete from public.moderation_queue as mq
      where mq.target_type='take' and mq.target_id=v_take.id;

    -- Rebuild ranking materializations after the take is no longer public,
    -- then discard its own metrics row.
    perform public.refresh_take_ranking(v_take.id);
    delete from public.take_metrics as tm where tm.take_id=v_take.id;
  end if;

  return query
  select t.id,t.storage_path,t.thumbnail_path
  from public.takes t where t.id=v_take.id;
end;
$$;

-- Storage bytes are removed through the Storage API by the Edge Function. The
-- paths stay on the hidden row until every bucket removal succeeds so the cron
-- recovery path can retry without ever losing the cleanup receipt.
create or replace function public.complete_take_media_cleanup(p_take_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.takes set
    storage_path=null,
    thumbnail_path=null,
    updated_at=now()
  where id=p_take_id and status='deleted';
$$;

-- Owner history excludes deleted media but returns a non-playable receipt for
-- its participation. This survives an app restart and lets the client explain
-- that ONE TAKE still prevents recording again today.
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
  where t.user_id=auth.uid() and t.status<>'deleted'

  union all

  select
    null::uuid,
    c.id,
    case when (select s.language_code from public.user_settings s where s.user_id=auth.uid())='de'
      then c.title_de else c.title_en end,
    c.challenge_date,
    null::text,
    null::text,
    case when t.status='deleted' then 'deleted' else null end,
    cp.status,
    0,
    0,
    0,
    coalesce(t.deleted_at,cp.created_at),
    c.publish_at<=now() and c.expires_at>now()
  from public.challenge_participations cp
  join public.challenges c on c.id=cp.challenge_id
  left join public.takes t on t.id=cp.take_id
  where cp.user_id=auth.uid()
    and (cp.take_id is null or t.status='deleted')
  order by challenge_date desc,created_at desc
  limit least(greatest(p_limit,1),100);
$$;

revoke all on function public.delete_my_take(uuid),
  public.complete_take_media_cleanup(uuid)
  from public,anon,authenticated;
grant execute on function public.delete_my_take(uuid) to authenticated;
grant execute on function public.complete_take_media_cleanup(uuid) to service_role;

commit;
