-- Keep operational failures out of the human content-review queue and prevent
-- staff from deciding their own takes. Participation/feed access remains
-- independent from every moderation outcome.
begin;

alter table public.moderation_queue
  add column if not exists automation_last_error text,
  add column if not exists automation_last_attempt_at timestamptz;

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
    if v_owner=auth.uid() then raise exception 'self_moderation_forbidden'; end if;
    update public.takes set
      status=case p_decision
        when 'publish' then 'published'::public.take_status
        when 'review' then 'under_review'::public.take_status
        when 'reject' then 'rejected'::public.take_status
        when 'hide' then 'removed'::public.take_status
        when 'remove' then 'removed'::public.take_status
        else status end,
      moderation_reason=p_reason,
      published_at=case when p_decision='publish' then now()
        when p_decision in ('review','reject','hide','remove') then null
        else published_at end
    where id=v_queue.target_id;
  elsif v_queue.target_type='comment' then
    select user_id into v_owner from public.comments where id=v_queue.target_id;
    if p_decision in ('remove','reject','hide') then update public.comments set status='removed' where id=v_queue.target_id; end if;
  else
    v_owner:=v_queue.target_id;
  end if;

  if p_decision='suspend' then update public.profiles set status='suspended' where id=v_owner;
  elsif p_decision='ban' then update public.profiles set status='banned' where id=v_owner; end if;
  insert into public.moderation_actions(queue_id,target_type,target_id,actor_id,decision,reason)
    values(p_queue_id,v_queue.target_type,v_queue.target_id,auth.uid(),p_decision::public.moderation_decision,p_reason);
  update public.moderation_queue set status='resolved',resolved_at=now() where id=p_queue_id;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,metadata)
    values(auth.uid(),'moderation_'||p_decision,v_queue.target_type::text,v_queue.target_id::text,
      jsonb_build_object('reason',p_reason,'suspend_until',p_suspend_until));
end;
$$;

revoke all on function public.admin_apply_moderation(uuid,text,text,timestamptz) from public,anon;
grant execute on function public.admin_apply_moderation(uuid,text,text,timestamptz) to authenticated;

commit;
