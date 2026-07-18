-- 체험자 내부 이메일 공개를 차단하고 기존 계정을 별칭 기반 로그인 주소로 이전하는 마이그레이션

create extension if not exists pgcrypto;

do $$
begin
  if exists (
    select 1
    from public.site_users as site_user
    join auth.users as auth_user on auth_user.id = site_user.user_id
    where auth_user.email <> 'u' || substring(
      encode(digest(lower(trim(site_user.nickname)), 'sha256'), 'hex')
      from 1 for 40
    ) || '@adlermind.co.kr'
  ) then
    raise exception '기존 Auth 이메일 이전이 끝나지 않았습니다. prepare_week1_login_email_migration.sql 결과대로 먼저 변경하세요.';
  end if;
end
$$;

alter table public.site_users drop column if exists email;

grant usage on schema public to authenticated;
revoke all on public.site_users from anon;
grant select, insert, update, delete on public.site_users to authenticated;

alter table public.site_users enable row level security;

drop policy if exists "닉네임 공개 조회" on public.site_users;
drop policy if exists "본인 닉네임 조회" on public.site_users;
create policy "본인 닉네임 조회" on public.site_users
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "본인 닉네임 등록" on public.site_users;
create policy "본인 닉네임 등록" on public.site_users
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "본인 닉네임 수정" on public.site_users;
create policy "본인 닉네임 수정" on public.site_users
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "본인 닉네임 삭제" on public.site_users;
create policy "본인 닉네임 삭제" on public.site_users
  for delete to authenticated
  using ((select auth.uid()) = user_id);
