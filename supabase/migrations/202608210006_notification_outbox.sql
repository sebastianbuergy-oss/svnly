-- Transactional notification outbox. Delivery is performed by send-apns.

alter table public.notifications
  add column delivery_status text not null default 'queued'
    check (delivery_status in ('queued','sending','sent','failed','no_device')),
  add column not_before timestamptz not null default now(),
  add column attempts smallint not null default 0 check (attempts between 0 and 10),
  add column sent_at timestamptz,
  add column last_error text,
  add column dedupe_key text unique;

create index notifications_delivery_idx on public.notifications(delivery_status,not_before,created_at)
  where delivery_status='queued';

create or replace function public.claim_notification_batch(p_limit integer default 100)
returns setof public.notifications
language plpgsql security definer set search_path = '' as $$
begin
  return query
  with candidates as (
    select id from public.notifications
    where delivery_status in ('queued','sending') and not_before<=now() and attempts<10
    order by created_at
    for update skip locked
    limit least(greatest(p_limit,1),100)
  )
  update public.notifications n
    set delivery_status='sending',attempts=n.attempts+1,last_error=null,
        not_before=now()+interval '15 minutes'
  from candidates c where n.id=c.id
  returning n.*;
end;
$$;

create or replace function public.enqueue_reaction_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select user_id into v_owner from public.takes where id=new.take_id and status='published';
  if v_owner is not null and v_owner<>new.user_id and not public.is_blocked(v_owner,new.user_id) then
    insert into public.notifications(user_id,category,title_key,body_key,data,dedupe_key)
    values(v_owner,'reaction','reaction_title','reaction_body',
      jsonb_build_object('take_id',new.take_id,'actor_id',new.user_id),
      'reaction:'||new.take_id||':'||new.user_id)
    on conflict(dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

create or replace function public.enqueue_comment_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select user_id into v_owner from public.takes where id=new.take_id and status='published';
  if v_owner is not null and v_owner<>new.user_id and not public.is_blocked(v_owner,new.user_id) then
    insert into public.notifications(user_id,category,title_key,body_key,data,dedupe_key)
    values(v_owner,'comment','comment_title','comment_body',
      jsonb_build_object('take_id',new.take_id,'comment_id',new.id,'actor_id',new.user_id),
      'comment:'||new.id)
    on conflict(dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

create or replace function public.enqueue_follow_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.follower_id<>new.followed_id and not public.is_blocked(new.follower_id,new.followed_id) then
    insert into public.notifications(user_id,category,title_key,body_key,data,dedupe_key)
    values(new.followed_id,'follower',
      case when new.status='pending' then 'follow_request_title' else 'new_follower_title' end,
      case when new.status='pending' then 'follow_request_body' else 'new_follower_body' end,
      jsonb_build_object('profile_id',new.follower_id,'status',new.status),
      'follow:'||new.follower_id||':'||new.followed_id||':'||new.status)
    on conflict(dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

create or replace function public.enqueue_moderation_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status is distinct from new.status and new.status in ('published','under_review','rejected','removed') then
    insert into public.notifications(user_id,category,title_key,body_key,data,dedupe_key)
    values(new.user_id,'moderation','moderation_'||new.status::text||'_title','moderation_'||new.status::text||'_body',
      jsonb_build_object('take_id',new.id,'status',new.status),
      'moderation:'||new.id||':'||new.status)
    on conflict(dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

create trigger reactions_notification after insert on public.reactions
for each row execute function public.enqueue_reaction_notification();
create trigger comments_notification after insert on public.comments
for each row execute function public.enqueue_comment_notification();
create trigger follows_notification after insert or update of status on public.follows
for each row execute function public.enqueue_follow_notification();
create trigger takes_moderation_notification after update of status on public.takes
for each row execute function public.enqueue_moderation_notification();

revoke all on function public.enqueue_reaction_notification(),
  public.enqueue_comment_notification(),public.enqueue_follow_notification(),
  public.enqueue_moderation_notification(),public.claim_notification_batch(integer)
  from public,anon,authenticated;
grant execute on function public.claim_notification_batch(integer) to service_role;
