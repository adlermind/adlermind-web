-- ADLER MIND 협동조합 — 문의 테이블
-- 실행 위치: Supabase 대시보드 > SQL Editor > New query
-- 프로젝트: jboceiacgczkqkhqcmqu (adlermindcoop 계정)

create table if not exists public.contact_messages (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  name       text not null,
  phone      text,
  email      text,
  category   text not null,
  message    text not null
);

alter table public.contact_messages enable row level security;

-- 누구나 문의 등록 가능
create policy "contact_insert" on public.contact_messages
  for insert with check (true);

-- 조회는 차단 (관리자만 Supabase 대시보드에서 확인)
create policy "contact_select" on public.contact_messages
  for select using (false);
