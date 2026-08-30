begin;

-- Storage upserts need SELECT in addition to INSERT/UPDATE. The original
-- controlled-read policy only became true after profiles.avatar_path was set,
-- so a user's first avatar upload could not complete its upsert response and
-- the profile RPC was never reached.
drop policy if exists avatars_owner_read on storage.objects;
create policy avatars_owner_read on storage.objects for select to authenticated using(
  bucket_id='avatars' and split_part(name,'/',1)=auth.uid()::text
);

drop policy if exists avatars_owner_delete on storage.objects;
create policy avatars_owner_delete on storage.objects for delete to authenticated using(
  bucket_id='avatars' and split_part(name,'/',1)=auth.uid()::text
);

-- Keep the five-argument Build 12 RPC intact while giving the fixed client an
-- explicit removal flag. New avatars use immutable/versioned object names so
-- a freshly saved image can never be hidden behind an old CDN cache entry.
create or replace function public.update_my_profile(
  p_username text,
  p_display_name text,
  p_bio text,
  p_country_code text,
  p_avatar_path text,
  p_remove_avatar boolean
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile public.profiles%rowtype;
  v_previous_avatar_path text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if trim(p_username) !~ '^[A-Za-z0-9._]{3,20}$'
     or lower(trim(p_username)) ~ '(svnly|admin|moderator|support|official|security|help)' then
    raise exception 'invalid_username';
  end if;
  if char_length(trim(p_display_name)) not between 2 and 40 then
    raise exception 'invalid_display_name';
  end if;
  if char_length(trim(p_bio))>160 then raise exception 'invalid_bio'; end if;
  if p_country_code !~ '^[A-Z]{2}$' then raise exception 'invalid_country'; end if;
  if p_remove_avatar and p_avatar_path is not null then
    raise exception 'conflicting_avatar_change';
  end if;
  if p_avatar_path is not null
     and p_avatar_path<>auth.uid()::text||'/avatar.jpg'
     and p_avatar_path !~ ('^'||auth.uid()::text||'/avatar-[0-9a-fA-F-]{36}\.jpg$') then
    raise exception 'invalid_avatar_path';
  end if;
  if p_avatar_path is not null and not exists(
    select 1 from storage.objects o
    where o.bucket_id='avatars' and o.name=p_avatar_path
      and split_part(o.name,'/',1)=auth.uid()::text
  ) then
    raise exception 'avatar_not_uploaded';
  end if;

  select avatar_path into v_previous_avatar_path
  from public.profiles where id=auth.uid() and status='active' for update;
  if not found then raise exception 'profile_not_found'; end if;

  update public.profiles set
    username=trim(p_username)::public.citext,
    display_name=trim(p_display_name),
    bio=trim(p_bio),
    country_code=p_country_code,
    avatar_path=case
      when p_remove_avatar then null
      when p_avatar_path is not null then p_avatar_path
      else avatar_path
    end,
    country_changed_at=case when country_code is distinct from p_country_code then now() else country_changed_at end,
    updated_at=now()
  where id=auth.uid() and status='active'
  returning * into v_profile;

  return jsonb_build_object(
    'id',v_profile.id,'username',v_profile.username,'display_name',v_profile.display_name,
    'bio',v_profile.bio,'country_code',v_profile.country_code,'avatar_path',v_profile.avatar_path,
    'previous_avatar_path',v_previous_avatar_path
  );
exception when unique_violation then
  raise exception 'username_taken';
end;
$$;

revoke all on function public.update_my_profile(text,text,text,text,text,boolean)
  from public,anon;
grant execute on function public.update_my_profile(text,text,text,text,text,boolean)
  to authenticated;

commit;
