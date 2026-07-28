-- 안건 게시판 표와 관리자 정리 권한
-- 실행 위치: 아들러마인드 Supabase(jboceiacgczkqkhqcmqu) SQL Editor
-- 여러 번 실행해도 안전합니다. 프로덕션 실행은 트리님이 직접 합니다.
--
-- 담는 것은 셋뿐입니다 — 게시자·안건 제목·안건의 필요성.
-- 총회 회차나 채택 여부는 지금 쓰지 않으므로 만들지 않습니다 (안 쓸 칸을 미리 만들지 않는다).

begin;

-- ── 1. 안건 게시판 표 ──────────────────────────────────────────
create table if not exists public.am_agenda (
  id         uuid primary key default gen_random_uuid(),
  author     text        not null,
  title      text        not null,
  reason     text        not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.am_agenda is
  '다음 총회에서 다룰 안건 제안. 조합원 마당 일정·모임 탭의 안건 게시판이 쓴다.';
comment on column public.am_agenda.author is
  '게시자 이름. 조합원 6인 중에서 고른 값이며 계정이 아니다.';

-- 고친 시각은 DB 가 적습니다.
-- ⚠ 다른 표와 함께 쓰는 공용 함수에 가지를 더하지 않고 이 표 전용 함수를 따로 만듭니다.
create or replace function public.touch_am_agenda()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists am_agenda_touch on public.am_agenda;
create trigger am_agenda_touch
  before update on public.am_agenda
  for each row execute function public.touch_am_agenda();

-- ── 2. GRANT ──────────────────────────────────────────────────
-- 조합원 내부 자료입니다. anon 에게는 아무 권한도 주지 않습니다.
revoke all on table public.am_agenda from anon;
grant select, insert, update, delete on table public.am_agenda to authenticated;

-- ── 3. RLS ────────────────────────────────────────────────────
-- 조합원 또는 관리자면 통과합니다.
-- ⚠ 작성자로 막지 않습니다. 표에 계정을 담지 않아 DB 가 작성자를 알 수 없습니다.
--    "자기 글만 수정"은 화면에서 담당자 이름으로 가릅니다. 조합원 내부 공간이라
--    이 정도로 두고, 계정으로 조이려면 표에 user_id 를 넣는 별도 작업이 필요합니다.
alter table public.am_agenda enable row level security;

drop policy if exists "안건 조회" on public.am_agenda;
create policy "안건 조회" on public.am_agenda
  for select to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "안건 생성" on public.am_agenda;
create policy "안건 생성" on public.am_agenda
  for insert to authenticated
  with check ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "안건 수정" on public.am_agenda;
create policy "안건 수정" on public.am_agenda
  for update to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()))
  with check ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "안건 삭제" on public.am_agenda;
create policy "안건 삭제" on public.am_agenda
  for delete to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

-- ── 4. 기획마당에 관리자 통로를 더합니다 ────────────────────────
-- 지금 am_ideas 정책은 is_active_member() 만 봅니다. 조합원이 아닌 관리자 전용 계정은
-- 화면에 버튼이 보여도 DB 에서 막힙니다. 관리자 조건을 함께 넣습니다.
-- 조합원 쪽 조건은 그대로 두므로 조합원이 하던 일은 달라지지 않습니다.
drop policy if exists "member_select" on public.am_ideas;
create policy "member_select" on public.am_ideas
  for select to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "member_insert" on public.am_ideas;
create policy "member_insert" on public.am_ideas
  for insert to authenticated
  with check ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "member_update" on public.am_ideas;
create policy "member_update" on public.am_ideas
  for update to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()))
  with check ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "member_delete" on public.am_ideas;
create policy "member_delete" on public.am_ideas
  for delete to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

commit;

-- ── 5. 한 표로 확인 ────────────────────────────────────────────
-- 모든 줄의 passed 가 true 여야 합니다.
select '1. am_agenda 표가 생겼다' as item,
       exists (select 1 from information_schema.tables
                where table_schema = 'public' and table_name = 'am_agenda') as passed
union all
select '2. 칸 다섯이 모두 있다',
       (select count(*) = 6 from information_schema.columns
         where table_schema = 'public' and table_name = 'am_agenda'
           and column_name in ('id','author','title','reason','created_at','updated_at'))
union all
select '3. am_agenda RLS 가 켜졌다',
       (select c.relrowsecurity from pg_class c
          join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname = 'am_agenda')
union all
select '4. am_agenda 정책 4개',
       (select count(*) = 4 from pg_policies
         where schemaname = 'public' and tablename = 'am_agenda')
union all
select '5. anon 은 안건을 볼 수 없다',
       not has_table_privilege('anon', 'public.am_agenda', 'SELECT')
union all
select '6. 고친 시각 트리거가 붙었다',
       exists (select 1 from pg_trigger
                where tgname = 'am_agenda_touch' and not tgisinternal)
union all
select '7. am_ideas 정책에 관리자 조건이 들어갔다',
       (select count(*) = 4 from pg_policies
         where schemaname = 'public' and tablename = 'am_ideas'
           and coalesce(qual, with_check) like '%is_active_admin%')
 order by item;
