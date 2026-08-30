-- V1 avoids a separate video-processing service. The signed app extracts three
-- fixed-time JPEGs from the final encoded MP4 and may insert each immutable
-- artifact exactly once for its own reserved take. Edge Functions keep
-- service-role access for validation and automated moderation.
begin;

create policy moderation_owner_frame_insert
on storage.objects for insert to authenticated
with check(
  bucket_id='moderation-artifacts'
  and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/frames/frame-0[1-3]\.jpg$'
  and exists(
    select 1 from public.takes t
    where t.id::text=split_part(name,'/',1)
      and t.user_id=auth.uid()
      and t.status='processing'
      and t.storage_path is null
  )
);

commit;
