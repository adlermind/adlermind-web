-- 일반 회원 닉네임 테이블 (Supabase Auth 연동)
-- 실행 전 Supabase 대시보드 > Authentication > Settings >
--   "Enable email confirmations" 를 OFF 로 설정해야 가입이 즉시 완료됩니다.

create table if not exists public.site_users (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade unique not null,
  nickname   text unique not null,
  created_at timestamptz default now()
);

grant usage on schema public to anon, authenticated;
grant select on public.site_users to anon;
grant insert, update on public.site_users to authenticated;

alter table public.site_users enable row level security;

drop policy if exists "닉네임 공개 조회" on public.site_users;
create policy "닉네임 공개 조회" on public.site_users
  for select using (true);

drop policy if exists "본인 닉네임 등록" on public.site_users;
create policy "본인 닉네임 등록" on public.site_users
  for insert with check (auth.uid() = user_id);

drop policy if exists "본인 닉네임 수정" on public.site_users;
create policy "본인 닉네임 수정" on public.site_users
  for update using (auth.uid() = user_id);
