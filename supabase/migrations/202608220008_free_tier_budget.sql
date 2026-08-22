-- Hard application-level limits for the $0 Supabase deployment. Supabase Free
-- itself has no paid overage path; these guards preserve headroom before its
-- service quotas are reached.

insert into public.app_config(key,value,is_public) values
  ('free_tier_mode','true',true),
  ('free_tier_storage_budget_bytes','805306368',true),
  ('free_tier_video_retention_days','21',true),
  ('free_tier_max_video_bytes','12582912',true)
on conflict(key) do update set value=excluded.value,is_public=excluded.is_public,updated_at=now();

create or replace function public.reserve_take_upload(
  p_attempt_id uuid, p_nonce uuid, p_duration_ms integer,
  p_file_size integer, p_look text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_attempt public.take_attempts%rowtype;
  v_take uuid;
  v_reserved_bytes bigint;
  v_budget_bytes constant bigint := 805306368; -- 768 MiB of the 1 GiB Free quota
begin
  select * into v_attempt from public.take_attempts
    where id=p_attempt_id and user_id=auth.uid() and nonce=p_nonce for update;
  if not found or v_attempt.status <> 'started' then raise exception 'invalid_attempt'; end if;
  if p_duration_ms not between 6800 and 7600 then raise exception 'invalid_duration'; end if;
  if p_file_size not between 1 and 12582912 then raise exception 'invalid_file_size'; end if;

  -- Serialize reservations so simultaneous uploads cannot race past the cap.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('svnly_free_tier_storage_budget'));
  select coalesce(sum(t.file_size),0) into v_reserved_bytes
  from public.takes t
  where t.status <> 'deleted'
    and (t.storage_path is not null or t.created_at > now() - interval '1 day');
  if v_reserved_bytes + p_file_size > v_budget_bytes then
    raise exception 'free_tier_storage_budget_exceeded';
  end if;

  insert into public.takes(user_id,challenge_id,attempt_id,duration_ms,file_size,live_look)
  values(auth.uid(),v_attempt.challenge_id,p_attempt_id,p_duration_ms,p_file_size,p_look)
  on conflict (attempt_id) do update set duration_ms=excluded.duration_ms,file_size=excluded.file_size
  returning id into v_take;
  update public.take_attempts set status='upload_reserved' where id=p_attempt_id;
  return v_take;
end;
$$;

revoke all on function public.reserve_take_upload(uuid,uuid,integer,integer,text)
  from public,anon;
grant execute on function public.reserve_take_upload(uuid,uuid,integer,integer,text)
  to authenticated;

commit;
