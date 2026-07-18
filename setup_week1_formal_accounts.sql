-- 일반회원과 조합원이 공유하는 이메일 회원 기반과 조합원 권한 연결을 구성합니다.

begin;

create table if not exists public.site_profiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 40),
  nickname     text not null check (char_length(btrim(nickname)) between 2 and 20),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.site_profiles enable row level security;
revoke all on public.site_profiles from anon;
revoke all on public.site_profiles from authenticated;
grant usage on schema public to authenticated;
grant select, update on public.site_profiles to authenticated;

drop policy if exists "본인 회원정보 조회" on public.site_profiles;
drop policy if exists "본인 회원정보 수정" on public.site_profiles;
create policy "본인 회원정보 조회" on public.site_profiles
  for select to authenticated
  using (user_id = (select auth.uid()));
create policy "본인 회원정보 수정" on public.site_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

drop trigger if exists bind_invited_member_after_auth_change on auth.users;
drop trigger if exists sync_formal_account_after_auth_change on auth.users;
drop function if exists public.bind_invited_member();

create or replace function private.sync_formal_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_type text := new.raw_user_meta_data ->> 'account_type';
  display_name text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  nickname text := btrim(coalesce(new.raw_user_meta_data ->> 'nickname', ''));
begin
  if new.email_confirmed_at is not null and account_type = 'formal' then
    if char_length(display_name) between 2 and 40
       and char_length(nickname) between 2 and 20 then
      insert into public.site_profiles (user_id, display_name, nickname)
      values (new.id, display_name, nickname)
      on conflict (user_id) do nothing;
    end if;

    update public.member_accounts
       set user_id = new.id,
           updated_at = now()
     where email = lower(new.email)
       and is_active = true
       and (user_id is null or user_id = new.id);
  end if;
  return new;
end;
$$;

revoke all on function private.sync_formal_account() from public, anon, authenticated;
create trigger sync_formal_account_after_auth_change
after insert or update of email, email_confirmed_at on auth.users
for each row execute function private.sync_formal_account();

insert into public.site_profiles (user_id, display_name, nickname)
select auth_user.id,
       btrim(auth_user.raw_user_meta_data ->> 'display_name'),
       btrim(auth_user.raw_user_meta_data ->> 'nickname')
  from auth.users as auth_user
 where auth_user.email_confirmed_at is not null
   and auth_user.raw_user_meta_data ->> 'account_type' = 'formal'
   and char_length(btrim(coalesce(auth_user.raw_user_meta_data ->> 'display_name', ''))) between 2 and 40
   and char_length(btrim(coalesce(auth_user.raw_user_meta_data ->> 'nickname', ''))) between 2 and 20
on conflict (user_id) do nothing;

update public.member_accounts as member
   set user_id = auth_user.id,
       updated_at = now()
  from auth.users as auth_user
 where member.email = lower(auth_user.email)
   and member.is_active = true
   and auth_user.email_confirmed_at is not null
   and auth_user.raw_user_meta_data ->> 'account_type' = 'formal'
   and (member.user_id is null or member.user_id = auth_user.id);

create or replace function public.is_active_member()
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.member_accounts
     where user_id = (select auth.uid())
       and is_active = true
  );
$$;

revoke all on function public.is_active_member() from public, anon;
grant execute on function public.is_active_member() to authenticated;

commit;

select user_id, display_name, nickname, created_at from public.site_profiles order by created_at;
select email, display_name, user_id, is_active from public.member_accounts order by display_name;
