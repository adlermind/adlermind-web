-- 일반 회원 닉네임 테이블 (Supabase Auth 연동)
-- 실행 전 Supabase 대시보드 > Authentication > Settings >
--   "Enable email confirmations" 를 OFF 로 설정해야 가입이 즉시 완료됩니다.

create table if not exists public.site_users (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade unique not null,
  nickname   text unique not null,
  created_at timestamptz default now()
);

grant usage on schema public to authenticated;
revoke all on public.site_users from anon;
grant select, insert, update, delete on public.site_users to authenticated;
grant usage on schema public to service_role;
grant insert on public.site_users to service_role;

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
