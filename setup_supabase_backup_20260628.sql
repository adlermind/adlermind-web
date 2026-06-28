-- ADLER MIND 협동조합 웹사이트 Supabase 초기 설정
-- 프로젝트: jboceiacgczkqkhqcmqu (adlermindcoop 계정)
-- 실행 위치: Supabase 대시보드 > SQL Editor > New query 에 붙여넣고 실행

-- ── 1. 게시판 (공지·회의록·서류) ──────────────────────
create table if not exists public.board_posts (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  category   text not null check (category in ('공지','회의록','서류')),
  title      text not null,
  content    text,
  author     text not null,
  file_url   text,
  file_name  text
);

alter table public.board_posts enable row level security;

create policy "board_select" on public.board_posts
  for select using (true);

create policy "board_insert" on public.board_posts
  for insert with check (true);

create policy "board_update" on public.board_posts
  for update using (true);

create policy "board_delete" on public.board_posts
  for delete using (true);

-- ── 2. 모임 일정 ──────────────────────────────────────
create table if not exists public.am_meetings (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz default now(),
  title         text not null,
  proposed_by   text not null,
  candidates    jsonb default '[]'::jsonb,
  status        text default 'open' check (status in ('open','decided')),
  decided_label text,
  decided_at    timestamptz
);

alter table public.am_meetings enable row level security;

create policy "meetings_select" on public.am_meetings for select using (true);
create policy "meetings_insert" on public.am_meetings for insert with check (true);
create policy "meetings_update" on public.am_meetings for update using (true);
create policy "meetings_delete" on public.am_meetings for delete using (true);

-- ── 3. 일정 투표 ──────────────────────────────────────
create table if not exists public.am_votes (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz default now(),
  meeting_id  uuid references public.am_meetings(id) on delete cascade,
  member_name text not null,
  answers     jsonb default '{}'::jsonb
);

alter table public.am_votes enable row level security;

create policy "votes_select" on public.am_votes for select using (true);
create policy "votes_insert" on public.am_votes for insert with check (true);
create policy "votes_update" on public.am_votes for update using (true);
create policy "votes_delete" on public.am_votes for delete using (true);

-- ── 4. 조합원 가용시간 ─────────────────────────────────
create table if not exists public.am_availability (
  id          uuid primary key default gen_random_uuid(),
  member_name text not null,
  week_start  date not null,
  slots       jsonb default '[]'::jsonb,
  updated_at  timestamptz default now(),
  unique(member_name, week_start)
);

alter table public.am_availability enable row level security;

create policy "avail_select" on public.am_availability for select using (true);
create policy "avail_insert" on public.am_availability for insert with check (true);
create policy "avail_update" on public.am_availability for update using (true);
create policy "avail_delete" on public.am_availability for delete using (true);
