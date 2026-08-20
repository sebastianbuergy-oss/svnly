begin;

alter table public.profiles enable row level security;
alter table public.user_private enable row level security;
alter table public.user_settings enable row level security;
alter table public.terms_acceptances enable row level security;
alter table public.challenges enable row level security;
alter table public.take_attempts enable row level security;
alter table public.takes enable row level security;
alter table public.take_metrics enable row level security;
alter table public.reactions enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.moderation_queue enable row level security;
alter table public.moderation_actions enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
alter table public.daily_rankings enable row level security;
alter table public.all_time_rankings enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.entitlements enable row level security;
alter table public.support_tickets enable row level security;
alter table public.account_deletion_jobs enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.app_config enable row level security;
alter table public.analytics_events enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (
  id=auth.uid() or public.is_staff() or (
    status='active' and not public.is_blocked(auth.uid(),id) and (
      not is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=id and f.status='accepted')
    )
  )
);
create policy profiles_staff_all on public.profiles for all to authenticated using(public.is_staff()) with check(public.is_staff());

create policy private_self_read on public.user_private for select to authenticated using(user_id=auth.uid());
create policy private_staff_read on public.user_private for select to authenticated using(public.is_staff());
create policy settings_self_read on public.user_settings for select to authenticated using(user_id=auth.uid());
create policy terms_self_read on public.terms_acceptances for select to authenticated using(user_id=auth.uid());

create policy challenges_active_read on public.challenges for select to authenticated using(
  status in ('active','scheduled','expired') or public.is_staff()
);
create policy challenges_staff_all on public.challenges for all to authenticated using(public.is_staff()) with check(public.is_staff());

create policy attempts_self_read on public.take_attempts for select to authenticated using(user_id=auth.uid());
create policy attempts_staff_read on public.take_attempts for select to authenticated using(public.is_staff());
create policy takes_self_read on public.takes for select to authenticated using(user_id=auth.uid());
create policy takes_staff_read on public.takes for select to authenticated using(public.is_staff());
create policy metrics_self_or_staff on public.take_metrics for select to authenticated using(
  public.is_staff() or exists(select 1 from public.takes t where t.id=take_id and t.user_id=auth.uid())
);

create policy reactions_self_read on public.reactions for select to authenticated using(user_id=auth.uid());
create policy comments_self_read on public.comments for select to authenticated using(user_id=auth.uid());
create policy follows_involving_self on public.follows for select to authenticated using(follower_id=auth.uid() or followed_id=auth.uid());
create policy blocks_self on public.blocks for select to authenticated using(blocker_id=auth.uid());
create policy reports_self on public.reports for select to authenticated using(reporter_id=auth.uid());

create policy moderation_staff_queue on public.moderation_queue for all to authenticated using(public.is_staff()) with check(public.is_staff());
create policy moderation_staff_actions on public.moderation_actions for all to authenticated using(public.is_staff()) with check(public.is_staff());
create policy audit_staff_read on public.admin_audit_log for select to authenticated using(public.is_staff());

create policy badges_authenticated_read on public.badges for select to authenticated using(true);
create policy user_badges_visible on public.user_badges for select to authenticated using(
  user_id=auth.uid() or exists(select 1 from public.profiles p where p.id=user_id and not public.is_blocked(auth.uid(),p.id) and (not p.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=p.id and f.status='accepted')))
);
create policy daily_rankings_read on public.daily_rankings for select to authenticated using(not public.is_blocked(auth.uid(),user_id));
create policy all_time_rankings_read on public.all_time_rankings for select to authenticated using(not public.is_blocked(auth.uid(),user_id));

create policy tokens_self_read on public.device_tokens for select to authenticated using(user_id=auth.uid());
create policy preferences_self_read on public.notification_preferences for select to authenticated using(user_id=auth.uid());
create policy notifications_self_read on public.notifications for select to authenticated using(user_id=auth.uid());
create policy notifications_self_update on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy entitlements_self_read on public.entitlements for select to authenticated using(user_id=auth.uid());
create policy support_self_read on public.support_tickets for select to authenticated using(user_id=auth.uid());
create policy deletion_self_read on public.account_deletion_jobs for select to authenticated using(user_id=auth.uid());
create policy config_public_read on public.app_config for select to authenticated using(is_public or public.is_staff());
create policy analytics_own_insert on public.analytics_events for insert to authenticated with check(user_id=auth.uid());
create policy analytics_staff_read on public.analytics_events for select to authenticated using(public.is_staff());

revoke insert,update,delete on all tables in schema public from anon,authenticated;
grant select on public.profiles,public.user_private,public.user_settings,public.terms_acceptances,
  public.challenges,public.take_attempts,public.takes,public.take_metrics,public.reactions,
  public.comments,public.follows,public.blocks,public.reports,public.moderation_queue,
  public.moderation_actions,public.badges,public.user_badges,public.daily_rankings,
  public.all_time_rankings,public.device_tokens,public.notification_preferences,
  public.notifications,public.entitlements,public.support_tickets,
  public.account_deletion_jobs,public.admin_audit_log,public.app_config to authenticated;
grant insert on public.analytics_events to authenticated;
grant update(read_at) on public.notifications to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('avatars','avatars',false,5242880,array['image/jpeg','image/png','image/webp']),
  ('takes','takes',false,12582912,array['video/mp4','video/quicktime']),
  ('take-thumbnails','take-thumbnails',false,1048576,array['image/jpeg','image/webp']),
  ('moderation-artifacts','moderation-artifacts',false,12582912,array['image/jpeg','image/webp','text/plain'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy avatars_owner_insert on storage.objects for insert to authenticated with check(
  bucket_id='avatars' and split_part(name,'/',1)=auth.uid()::text
);
create policy avatars_owner_update on storage.objects for update to authenticated using(
  bucket_id='avatars' and split_part(name,'/',1)=auth.uid()::text
) with check(bucket_id='avatars' and split_part(name,'/',1)=auth.uid()::text);
create policy avatars_controlled_read on storage.objects for select to authenticated using(
  bucket_id='avatars' and exists(
    select 1 from public.profiles p where p.avatar_path=name and (
      p.id=auth.uid() or (not public.is_blocked(auth.uid(),p.id) and (not p.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=p.id and f.status='accepted')))
    )
  )
);

create policy takes_expected_insert on storage.objects for insert to authenticated with check(
  bucket_id='takes' and split_part(name,'/',1)=auth.uid()::text
  and right(lower(name),4)='.mp4'
  and exists(select 1 from public.takes t where t.user_id=auth.uid() and t.id=split_part(name,'/',3)::uuid and t.storage_path is null and t.status='processing')
);
create policy takes_authorized_read on storage.objects for select to authenticated using(
  bucket_id='takes' and exists(
    select 1 from public.takes t join public.profiles p on p.id=t.user_id
    where t.storage_path=name and (
      t.user_id=auth.uid() or public.is_staff() or (
        t.status='published' and public.has_valid_take_today()
        and not public.is_blocked(auth.uid(),t.user_id)
        and (not p.is_private or exists(select 1 from public.follows f where f.follower_id=auth.uid() and f.followed_id=t.user_id and f.status='accepted'))
      )
    )
  )
);
create policy thumbnails_authorized_read on storage.objects for select to authenticated using(
  bucket_id='take-thumbnails' and exists(
    select 1 from public.takes t join public.profiles p on p.id=t.user_id
    where t.thumbnail_path=name and (t.user_id=auth.uid() or public.is_staff() or (t.status='published' and public.has_valid_take_today() and not public.is_blocked(auth.uid(),t.user_id) and not p.is_private))
  )
);
create policy moderation_staff_only on storage.objects for all to authenticated using(
  bucket_id='moderation-artifacts' and public.is_staff()
) with check(bucket_id='moderation-artifacts' and public.is_staff());

revoke all on function public.complete_profile(text,text,text,text,text,date,boolean,text,text,text) from public,anon;
revoke all on function public.issue_take_attempt() from public,anon;
revoke all on function public.mark_attempt_started(uuid) from public,anon;
revoke all on function public.request_technical_retry(uuid,text,jsonb) from public,anon;
revoke all on function public.reserve_take_upload(uuid,uuid,integer,integer,text) from public,anon;
revoke all on function public.finalize_take(uuid,uuid,text,integer,integer) from public,anon;
grant execute on function public.complete_profile(text,text,text,text,text,date,boolean,text,text,text),
  public.current_challenge(),public.has_valid_take_today(),public.issue_take_attempt(),
  public.mark_attempt_started(uuid),public.request_technical_retry(uuid,text,jsonb),
  public.reserve_take_upload(uuid,uuid,integer,integer,text),
  public.finalize_take(uuid,uuid,text,integer,integer),public.get_daily_feed(text,integer,integer),
  public.set_reaction(uuid,text),public.create_comment(uuid,text),
  public.get_comments(uuid,integer,integer),public.delete_comment(uuid),
  public.follow_profile(uuid),public.block_profile(uuid),public.unblock_profile(uuid),
  public.get_blocked_users(),public.create_report(text,uuid,text,text),
  public.get_rankings(text,text,integer),public.get_my_profile(),
  public.update_user_setting(text,jsonb),public.create_support_ticket(text,text),
  public.request_account_deletion() to authenticated;

commit;
