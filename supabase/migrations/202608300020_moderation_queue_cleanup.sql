-- Polymorphic moderation targets cannot use a direct foreign key to takes.
-- Keep the queue consistent when a take is removed by account deletion or
-- retention cleanup, and repair any pre-existing orphaned take targets.
begin;

create or replace function public.cleanup_deleted_take_moderation_queue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.moderation_queue
  where target_type = 'take' and target_id = old.id;
  return old;
end;
$$;

revoke all on function public.cleanup_deleted_take_moderation_queue()
from public, anon, authenticated;

drop trigger if exists takes_cleanup_moderation_queue on public.takes;
create trigger takes_cleanup_moderation_queue
after delete on public.takes
for each row execute function public.cleanup_deleted_take_moderation_queue();

delete from public.moderation_queue q
where q.target_type = 'take'
  and not exists(select 1 from public.takes t where t.id = q.target_id);

commit;
