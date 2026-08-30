-- PostgreSQL named function arguments use `=>`. The previous `=` syntax was
-- parsed as a column comparison by the production pg_net version, so the cron
-- tick succeeded without ever enqueuing the Edge Function request.
begin;

create or replace function public.invoke_scheduled_edge_job()
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text; v_request_id bigint;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name='project_url' limit 1;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name='cron_secret' limit 1;
  if v_url is null or v_secret is null then return null; end if;
  select net.http_post(
    url => rtrim(v_url,'/')||'/functions/v1/scheduled-jobs',
    body => '{}'::jsonb,
    params => '{}'::jsonb,
    headers => jsonb_build_object('Content-Type','application/json','x-cron-secret',v_secret),
    timeout_milliseconds => 55000
  ) into v_request_id;
  return v_request_id;
end;
$$;

revoke all on function public.invoke_scheduled_edge_job() from public,anon,authenticated;
grant execute on function public.invoke_scheduled_edge_job() to service_role;

commit;
