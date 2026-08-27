begin;

-- Participation is proven by a completed upload, not by the later moderation
-- outcome. A rejected take must therefore not retroactively lock the feed.
create or replace function public.has_valid_take_today()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.take_attempts a
    join public.takes t
      on t.attempt_id = a.id
     and t.user_id = a.user_id
     and t.challenge_id = a.challenge_id
    join public.challenges c on c.id = a.challenge_id
    where a.user_id = auth.uid()
      and a.status = 'finalized'
      and a.finalized_at is not null
      and t.storage_path is not null
      and t.status in ('processing','published','under_review','rejected')
      and c.publish_at <= now()
      and c.expires_at > now()
  );
$$;

-- Reserving an upload must be idempotent. Otherwise any network interruption
-- after the reservation leaves the locally protected take impossible to retry.
create or replace function public.reserve_take_upload(
  p_attempt_id uuid, p_nonce uuid, p_duration_ms integer,
  p_file_size integer, p_look text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_attempt public.take_attempts%rowtype;
  v_take uuid;
  v_reserved_bytes bigint;
  v_budget_bytes constant bigint := 805306368;
begin
  select * into v_attempt from public.take_attempts
    where id=p_attempt_id and user_id=auth.uid() and nonce=p_nonce for update;
  if not found or v_attempt.status not in ('started','upload_reserved') then
    raise exception 'invalid_attempt';
  end if;
  if p_duration_ms not between 6800 and 7600 then raise exception 'invalid_duration'; end if;
  if p_file_size not between 1 and 12582912 then raise exception 'invalid_file_size'; end if;

  if v_attempt.status = 'started' then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('svnly_free_tier_storage_budget'));
    select coalesce(sum(t.file_size),0) into v_reserved_bytes
    from public.takes t
    where t.status <> 'deleted'
      and (t.storage_path is not null or t.created_at > now() - interval '1 day');
    if v_reserved_bytes + p_file_size > v_budget_bytes then
      raise exception 'free_tier_storage_budget_exceeded';
    end if;
  end if;

  insert into public.takes(user_id,challenge_id,attempt_id,duration_ms,file_size,live_look)
  values(auth.uid(),v_attempt.challenge_id,p_attempt_id,p_duration_ms,p_file_size,p_look)
  on conflict (attempt_id) do update
    set duration_ms=excluded.duration_ms,file_size=excluded.file_size,live_look=excluded.live_look
  returning id into v_take;
  update public.take_attempts set status='upload_reserved'
    where id=p_attempt_id and status='started';
  return v_take;
end;
$$;

revoke all on function public.reserve_take_upload(uuid,uuid,integer,integer,text)
  from public,anon;
grant execute on function public.reserve_take_upload(uuid,uuid,integer,integer,text)
  to authenticated;

commit;
