-- 조합원 명부와 Supabase 초대 계정을 안전하게 연결하는 기반을 만든다.

begin;

create table if not exists public.member_accounts (
  email        text primary key,
  display_name text not null,
  user_id      uuid unique references auth.users(id) on delete set null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint member_accounts_email_lowercase check (email = lower(email))
);

alter table public.member_accounts enable row level security;
revoke all on public.member_accounts from anon;
revoke all on public.member_accounts from authenticated;
grant usage on schema public to authenticated;
grant select on public.member_accounts to authenticated;

drop policy if exists "조합원 본인 계정 조회" on public.member_accounts;
create policy "조합원 본인 계정 조회" on public.member_accounts
  for select to authenticated
  using (user_id = (select auth.uid()) and is_active = true);

create or replace function public.bind_invited_member()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.email_confirmed_at is not null then
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

revoke all on function public.bind_invited_member() from public, anon, authenticated;

drop trigger if exists bind_invited_member_after_auth_change on auth.users;
create trigger bind_invited_member_after_auth_change
after insert or update of email, email_confirmed_at on auth.users
for each row execute function public.bind_invited_member();

update public.member_accounts as member
   set user_id = auth_user.id,
       updated_at = now()
  from auth.users as auth_user
 where member.email = lower(auth_user.email)
   and member.is_active = true
   and auth_user.email_confirmed_at is not null
   and (member.user_id is null or member.user_id = auth_user.id);

commit;

select email, display_name, user_id, is_active
  from public.member_accounts
 order by display_name;
