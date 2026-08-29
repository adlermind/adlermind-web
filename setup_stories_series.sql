-- [아들러 이야기] 연재 — 조합원이 자기 주제로 글을 이어 쓰는 묶음입니다.
-- setup_stories.sql 을 먼저 실행한 뒤에 실행하세요.
-- 이미 만든 표와 정책은 건드리지 않고 표 하나와 열 하나만 더합니다.
--
-- 왜 카테고리가 아니라 연재인가:
--   조합원마다 쓰고 싶은 주제가 따로 있습니다(아로마 · 미술치료와 명상 · 아들러 부모교육).
--   공통 카테고리로 나누면 "누가 쓰든 같은 주제는 한군데"가 되지만,
--   여기서 필요한 것은 "한 사람이 한 주제를 이어 쓰는 자리"입니다. 책 한 권의 목차에 가깝습니다.
--   그래서 묶음마다 주인(owner_user_id)을 두고, 글에서 그 묶음을 가리키게 했습니다.
--
-- 왜 이름을 코드에 박지 않는가:
--   소식 게시판(board_posts)은 category 에 check 제약을 걸어 두어 칸 하나 늘리려면 표를 고쳐야 합니다.
--   같은 실수를 되풀이하지 않으려고 연재는 표로 두고 관리자 화면에서 늘리게 했습니다.

begin;

create table if not exists public.story_series (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  title         text not null,              -- 예 · 아로마와 마음
  description   text,                       -- 목록 위에 한두 줄로 보입니다
  owner_user_id uuid references auth.users(id) on delete set null,
  is_active     boolean not null default true,
  sort_order    integer not null default 0
);

-- 글이 어느 연재에 속하는지. 비어 있으면 연재에 묶이지 않은 낱글입니다.
-- 연재를 지워도 글은 남고 이 값만 비워집니다(on delete set null).
alter table public.am_stories
  add column if not exists series_id uuid references public.story_series(id) on delete set null;

create index if not exists am_stories_series_idx
  on public.am_stories (series_id, published_at desc);

-- ── 권한 ──────────────────────────────────────────────
-- 연재 목록은 로그인하지 않은 사람도 봐야 목록 화면의 탭을 그릴 수 있습니다.
revoke all on public.story_series from anon, authenticated;
grant select on public.story_series to anon;
grant select, insert, update, delete on public.story_series to authenticated;
alter table public.story_series enable row level security;

drop policy if exists "연재 조회" on public.story_series;
create policy "연재 조회" on public.story_series
  for select to anon, authenticated using (true);

-- 연재를 만들고 이름을 고치는 일은 관리자만 합니다.
-- 글쓴이가 스스로 연재를 늘리면 비슷한 이름이 여럿 생겨 목록이 흩어집니다.
drop policy if exists "연재 등록" on public.story_series;
create policy "연재 등록" on public.story_series
  for insert to authenticated with check ((select public.is_active_admin()));

drop policy if exists "연재 수정" on public.story_series;
create policy "연재 수정" on public.story_series
  for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));

drop policy if exists "연재 삭제" on public.story_series;
create policy "연재 삭제" on public.story_series
  for delete to authenticated using ((select public.is_active_admin()));

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'am_stories' and column_name = 'series_id';

select policyname, roles, cmd
  from pg_policies
 where schemaname = 'public' and tablename = 'story_series'
 order by cmd, policyname;
