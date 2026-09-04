-- ADLER MIND 협동조합 · 후원회원 명부 (2026-09-02)
-- 실행 위치 · Supabase jboceiacgczkqkhqcmqu > SQL Editor
-- 실행 주체 · 트리님이 직접 실행합니다.
--
-- 표 하나 · am_supporters (후원회원 신청)
-- 개인정보가 들어가므로 anon 에게 select 를 열지 않습니다. 넣기만 허용합니다.

create table if not exists public.am_supporters (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,              -- 이름
  phone          text not null,              -- 연락처
  email          text,                       -- 이메일 (뉴스레터 받을 곳)
  depositor      text,                       -- 입금자명이 이름과 다를 때
  joined_at      timestamptz default now(),  -- 가입 신청일
  paid_at        date,                       -- 회비 입금 확인일 (관리자가 넣습니다)
  status         text default 'pending',     -- pending 입금대기 | active 후원회원 | withdrawn 탈퇴
  privacy_agree  boolean not null default false,  -- 개인정보 수집 동의
  news_agree     boolean default false,      -- 뉴스레터 수신 동의
  memo           text,                       -- 관리자 메모
  created_at     timestamptz default now()
);

-- GRANT 와 RLS 는 서로 다른 두 층위입니다. 둘 다 있어야 합니다.
grant usage on schema public to anon;
grant insert on public.am_supporters to anon;

alter table public.am_supporters enable row level security;

drop policy if exists "누구나 후원회원 신청을 넣습니다" on public.am_supporters;
create policy "누구나 후원회원 신청을 넣습니다"
  on public.am_supporters for insert with check (true);

-- 관리자가 명부를 볼 때는 Supabase 대시보드의 Table Editor 에서 봅니다.
-- 홈페이지 관리자 화면에 명부를 붙이는 일은 다음 작업으로 둡니다.
