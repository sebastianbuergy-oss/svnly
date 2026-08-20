begin;

create or replace function public.accept_follow_request(p_follower_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.follows set status='accepted',updated_at=now()
  where follower_id=p_follower_id and followed_id=auth.uid() and status='pending';
  if not found then raise exception 'request_not_found'; end if;
  perform public.recount_follow_totals(auth.uid());
  perform public.recount_follow_totals(p_follower_id);
end;
$$;

create or replace function public.decline_follow_request(p_follower_id uuid)
returns void language sql security definer set search_path = '' as $$
  delete from public.follows where follower_id=p_follower_id and followed_id=auth.uid() and status='pending';
$$;

create or replace function public.remove_follower(p_follower_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.follows where follower_id=p_follower_id and followed_id=auth.uid();
  perform public.recount_follow_totals(auth.uid());
  perform public.recount_follow_totals(p_follower_id);
end;
$$;

create or replace function public.get_follow_requests()
returns table(profile_id uuid,username text,display_name text,requested_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.id,p.username::text,p.display_name,f.created_at
  from public.follows f join public.profiles p on p.id=f.follower_id
  where f.followed_id=auth.uid() and f.status='pending' and not public.is_blocked(auth.uid(),p.id)
  order by f.created_at;
$$;

create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_required'; end if;
  return jsonb_build_object(
    'active_users_today',(select count(distinct user_id) from public.analytics_events where occurred_at>=date_trunc('day',now())),
    'takes_today',(select count(*) from public.takes where created_at>=date_trunc('day',now())),
    'upload_failures',(select count(*) from public.take_attempts where status='technical_failure' and issued_at>=date_trunc('day',now())),
    'open_reports',(select count(*) from public.reports where status in ('open','reviewing')),
    'under_review',(select count(*) from public.takes where status='under_review'),
    'suspended_users',(select count(*) from public.profiles where status in ('suspended','banned')),
    'challenge',(select to_jsonb(c) from (select id,challenge_date,title_en,status from public.challenges where publish_at<=now() and expires_at>now() limit 1)c)
  );
end;
$$;

create or replace function public.admin_moderation_queue(p_limit integer default 100)
returns table(queue_id uuid,target_type text,target_id uuid,source text,priority smallint,created_at timestamptz,automated_scores jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_required'; end if;
  return query select q.id,q.target_type::text,q.target_id,q.source,q.priority,q.created_at,q.automated_scores
  from public.moderation_queue q where q.status='open'
  order by q.priority desc,q.created_at limit least(p_limit,100);
end;
$$;

create or replace function public.admin_apply_moderation(
  p_queue_id uuid,p_decision text,p_reason text,p_suspend_until timestamptz default null
) returns void language plpgsql security definer set search_path = '' as $$
declare v_queue public.moderation_queue%rowtype; v_owner uuid;
begin
  if not public.is_staff() then raise exception 'staff_required'; end if;
  if p_decision not in ('publish','review','reject','hide','remove','warn','suspend','ban') then raise exception 'invalid_decision'; end if;
  select * into v_queue from public.moderation_queue where id=p_queue_id and status='open' for update;
  if not found then raise exception 'queue_item_not_found'; end if;
  if v_queue.target_type='take' then
    select user_id into v_owner from public.takes where id=v_queue.target_id;
    update public.takes set
      status=case p_decision when 'publish' then 'published'::public.take_status when 'reject' then 'rejected'::public.take_status when 'remove' then 'removed'::public.take_status when 'hide' then 'under_review'::public.take_status else status end,
      moderation_reason=p_reason,
      published_at=case when p_decision='publish' then now() else published_at end
    where id=v_queue.target_id;
  elsif v_queue.target_type='comment' then
    select user_id into v_owner from public.comments where id=v_queue.target_id;
    if p_decision in ('remove','reject','hide') then update public.comments set status='removed' where id=v_queue.target_id; end if;
  else v_owner:=v_queue.target_id; end if;
  if p_decision='suspend' then update public.profiles set status='suspended' where id=v_owner;
  elsif p_decision='ban' then update public.profiles set status='banned' where id=v_owner; end if;
  insert into public.moderation_actions(queue_id,target_type,target_id,actor_id,decision,reason)
    values(p_queue_id,v_queue.target_type,v_queue.target_id,auth.uid(),p_decision::public.moderation_decision,p_reason);
  update public.moderation_queue set status='resolved',resolved_at=now() where id=p_queue_id;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,metadata)
    values(auth.uid(),'moderation_'||p_decision,v_queue.target_type::text,v_queue.target_id::text,jsonb_build_object('reason',p_reason,'suspend_until',p_suspend_until));
end;
$$;

create or replace function public.admin_upsert_challenge(
  p_id uuid,p_date date,p_title_en text,p_title_de text,p_description_en text,p_description_de text,p_category text,p_status text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not public.is_staff() then raise exception 'staff_required'; end if;
  if p_status not in ('draft','scheduled','active','cancelled') then raise exception 'invalid_status'; end if;
  insert into public.challenges(id,challenge_date,title_en,title_de,description_en,description_de,category,status,publish_at,expires_at,created_by)
  values(coalesce(p_id,gen_random_uuid()),p_date,p_title_en,p_title_de,p_description_en,p_description_de,p_category,p_status::public.challenge_status,p_date::timestamptz,p_date::timestamptz+interval '1 day',auth.uid())
  on conflict(id) do update set challenge_date=excluded.challenge_date,title_en=excluded.title_en,title_de=excluded.title_de,description_en=excluded.description_en,description_de=excluded.description_de,category=excluded.category,status=excluded.status,publish_at=excluded.publish_at,expires_at=excluded.expires_at
  returning id into v_id;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id) values(auth.uid(),'challenge_upsert','challenge',v_id::text);
  return v_id;
end;
$$;

revoke all on function public.admin_dashboard(),public.admin_moderation_queue(integer),public.admin_apply_moderation(uuid,text,text,timestamptz),public.admin_upsert_challenge(uuid,date,text,text,text,text,text,text) from public,anon;
grant execute on function public.accept_follow_request(uuid),public.decline_follow_request(uuid),public.remove_follower(uuid),public.get_follow_requests() to authenticated;
grant execute on function public.admin_dashboard(),public.admin_moderation_queue(integer),public.admin_apply_moderation(uuid,text,text,timestamptz),public.admin_upsert_challenge(uuid,date,text,text,text,text,text,text) to authenticated;

commit;
