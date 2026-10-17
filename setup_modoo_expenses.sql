-- [모두의 창업] 결제 요청 · 카드 집행기록 · AI 솔루션 함께 쓰기 · 사용 기록
-- 설계 · 계획서\02_홈페이지\인계_모두의창업_집행기록_20261017.md (4·5·8절)
--
-- 조합 회계장부(accounting_records · receipts 버킷)와 표·버킷·함수를 하나도 공유하지 않습니다.
-- 창업활동자금 카드 지출이 조합 장부와 섞이면 환수 사유가 되기 때문입니다.
-- anon 에는 아무 권한도 주지 않습니다.
--
-- 먼저 있어야 하는 것 · public.is_active_member() · public.is_active_admin() · private 스키마
-- 여러 번 실행해도 됩니다 (if not exists · drop policy if exists · on conflict).
-- 맨 아래 진단 표의 ok 칸이 모두 true 인지 확인해 주세요.

begin;

-- ── 0. 관리 담당 ───────────────────────────────────────
-- 넣고 빼기는 SQL Editor 에서만 합니다. 화면에서는 아무것도 쓰지 않습니다.
create table if not exists public.modoo_managers (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at   timestamptz not null default now()
);

revoke all on public.modoo_managers from anon;
revoke all on public.modoo_managers from authenticated;
grant select on public.modoo_managers to authenticated;

alter table public.modoo_managers enable row level security;

-- 판정 함수가 읽을 수 있도록 본인 행만 보입니다.
drop policy if exists "modoo_mgr_select" on public.modoo_managers;
create policy "modoo_mgr_select" on public.modoo_managers
  for select to authenticated
  using (user_id = (select auth.uid()));

-- 이 표에 있으면서 활성 조합원일 때만 참
create or replace function public.is_modoo_manager()
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.modoo_managers m
      join public.member_accounts a on a.user_id = m.user_id
     where m.user_id = (select auth.uid())
       and a.is_active = true
  );
$$;

revoke all on function public.is_modoo_manager() from public, anon;
grant execute on function public.is_modoo_manager() to authenticated;

-- 처음 채우기 · 이경숙(이사장) · 박정연(회계) · 김이수 (2026-10-17 트리님 결정)
-- 이름은 여기서 한 번 찾는 데만 씁니다. 빠진 분은 진단에 숫자로 드러납니다.
insert into public.modoo_managers (user_id, display_name)
select user_id, display_name
  from public.member_accounts
 where display_name in ('이경숙', '박정연', '김이수')
   and user_id is not null
on conflict (user_id) do nothing;

-- ── 1. 표 세 개 ────────────────────────────────────────

-- 1-1. 결제 요청과 카드 집행 한 건 (요청이 결제되면 같은 행이 집행기록이 된다)
create table if not exists public.modoo_expenses (
  id               uuid primary key default gen_random_uuid(),
  status           text not null default '요청'
                     check (status in ('요청','결제함','안 하기로 함')),

  -- 요청할 때 적는 칸
  item_name        text not null,                 -- 세부 품목·내용 (붙임2 품목명)
  budget_item      text not null check (budget_item in
                     ('재료구입비','외주용역비','문헌구입비','지급수수료','여비·회의비')),
  relevance        text not null,                 -- 창업 아이템(웹앱)과의 직접 연관성
  expected_amount  integer check (expected_amount > 0),
  buy_link         text,
  needed_by        date,
  is_online        boolean not null default false,
  is_asset         boolean not null default false,
  requested_by     text not null,                 -- 적은 사람 이름
  user_id          uuid references auth.users(id) on delete set null,

  -- 결제한 뒤 적는 칸 (붙임1·붙임2)
  spent_on         date,                          -- 집행일자
  merchant         text,                          -- 거래처명
  calc_basis       text,                          -- 산출근거
  quantity         text,                          -- 수량
  amount           integer check (amount > 0),    -- 최종 실제 집행금액(부가세 포함)
  adjust           text not null default '없음'
                     check (adjust in ('없음','취소','부분취소','잔액보전')),
  usage_result     text,                          -- 활용 결과
  attendees        text,                          -- 회의비 목적·동석자
  preapproval      text not null default '해당 없음'
                     check (preapproval in ('해당 없음','요청함','승인됨')),
  evidence         jsonb not null default '[]',   -- [{kind, name, size, path}]
  reject_reason    text,
  recorded_by      text,
  note             text,

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (jsonb_typeof(evidence) = 'array'),
  check (status <> '결제함' or (spent_on is not null and merchant is not null and amount is not null))
);

-- 1-2. AI 솔루션 함께 쓰기 (아이디·비밀번호 칸은 두지 않는다)
create table if not exists public.modoo_ai_solutions (
  id            uuid primary key default gen_random_uuid(),
  use_month     text not null check (use_month in ('2026-11','2026-12')),
  name          text not null,
  supplier      text,
  monthly_fee   integer not null check (monthly_fee >= 0),
  purpose       text not null,
  status        text not null default '제안'
                  check (status in ('제안','신청함','계정 받음','안 하기로 함')),
  users         text,                             -- 함께 쓰는 조합원 이름 (쉼표로)
  applied_on    date,
  proposed_by   text not null,
  user_id       uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 1-3. AI 솔루션 사용 기록 (세 줄 후기)
create table if not exists public.modoo_ai_notes (
  id            uuid primary key default gen_random_uuid(),
  solution_id   uuid not null references public.modoo_ai_solutions(id) on delete cascade,
  used_for      text not null,
  learned       text not null,
  changed       text,
  written_by    text not null,
  user_id       uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists modoo_ai_notes_solution_idx on public.modoo_ai_notes (solution_id);

-- ── 2. 권한 ────────────────────────────────────────────
revoke all on public.modoo_expenses, public.modoo_ai_solutions, public.modoo_ai_notes from anon;
grant select, insert, update, delete
   on public.modoo_expenses, public.modoo_ai_solutions, public.modoo_ai_notes
   to authenticated;

-- ── 3. RLS ─────────────────────────────────────────────
alter table public.modoo_expenses enable row level security;
alter table public.modoo_ai_solutions enable row level security;
alter table public.modoo_ai_notes enable row level security;

-- 3-1. modoo_expenses
drop policy if exists "modoo_exp_select" on public.modoo_expenses;
create policy "modoo_exp_select" on public.modoo_expenses
  for select to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

-- 올리기 · 본인 계정으로만. 조합원은 「요청」만, 「결제함」으로 바로 적기는 관리 담당·관리자만
drop policy if exists "modoo_exp_insert" on public.modoo_expenses;
create policy "modoo_exp_insert" on public.modoo_expenses
  for insert to authenticated
  with check (
    ((select public.is_active_member()) or (select public.is_active_admin()))
    and user_id = (select auth.uid())
    and (status = '요청' or (select public.is_modoo_manager()) or (select public.is_active_admin()))
  );

-- 고치기 · 관리 담당·관리자는 모든 행, 조합원은 자기 행이 「요청」일 때만(고친 뒤에도 「요청」)
drop policy if exists "modoo_exp_update" on public.modoo_expenses;
create policy "modoo_exp_update" on public.modoo_expenses
  for update to authenticated
  using ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid()) and status = '요청'))
  with check ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid()) and status = '요청'));

-- 지우기 · 관리 담당·관리자, 또는 올린 본인이 「요청」일 때만 (결제된 행은 12. 1. 제출 근거)
drop policy if exists "modoo_exp_delete" on public.modoo_expenses;
create policy "modoo_exp_delete" on public.modoo_expenses
  for delete to authenticated
  using ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid()) and status = '요청'));

-- 3-2. modoo_ai_solutions
-- 「함께 쓰기」는 표를 직접 고치지 않고 아래 6절 함수로만 한다 (2026-10-17 트리님 결정).
-- 그래서 고치기는 관리 담당·관리자, 그리고 올린 본인이 「제안」일 때만이다.
drop policy if exists "modoo_ai_select" on public.modoo_ai_solutions;
create policy "modoo_ai_select" on public.modoo_ai_solutions
  for select to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "modoo_ai_insert" on public.modoo_ai_solutions;
create policy "modoo_ai_insert" on public.modoo_ai_solutions
  for insert to authenticated
  with check (
    ((select public.is_active_member()) or (select public.is_active_admin()))
    and user_id = (select auth.uid())
    and (status = '제안' or (select public.is_modoo_manager()) or (select public.is_active_admin()))
  );

drop policy if exists "modoo_ai_update" on public.modoo_ai_solutions;
create policy "modoo_ai_update" on public.modoo_ai_solutions
  for update to authenticated
  using ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid()) and status = '제안'))
  with check ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid()) and status = '제안'));

-- 「신청함」 이후는 지우지 말고 「안 하기로 함」으로 둔다 (지우면 사용 기록도 함께 지워진다)
drop policy if exists "modoo_ai_delete" on public.modoo_ai_solutions;
create policy "modoo_ai_delete" on public.modoo_ai_solutions
  for delete to authenticated
  using ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid()) and status = '제안'));

-- 3-3. modoo_ai_notes
drop policy if exists "modoo_note_select" on public.modoo_ai_notes;
create policy "modoo_note_select" on public.modoo_ai_notes
  for select to authenticated
  using ((select public.is_active_member()) or (select public.is_active_admin()));

drop policy if exists "modoo_note_insert" on public.modoo_ai_notes;
create policy "modoo_note_insert" on public.modoo_ai_notes
  for insert to authenticated
  with check (
    ((select public.is_active_member()) or (select public.is_active_admin()))
    and user_id = (select auth.uid())
  );

drop policy if exists "modoo_note_update" on public.modoo_ai_notes;
create policy "modoo_note_update" on public.modoo_ai_notes
  for update to authenticated
  using ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid())))
  with check ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid())));

drop policy if exists "modoo_note_delete" on public.modoo_ai_notes;
create policy "modoo_note_delete" on public.modoo_ai_notes
  for delete to authenticated
  using ((select public.is_modoo_manager()) or (select public.is_active_admin())
         or ((select public.is_active_member()) and user_id = (select auth.uid())));

-- ── 4. 고친 시각 · 표마다 전용 트리거 (공용 함수 재사용 금지 · 심지 2026-07-25 사고) ──
create or replace function private.modoo_expenses_touch()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.modoo_ai_solutions_touch()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.modoo_ai_notes_touch()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists modoo_expenses_touch on public.modoo_expenses;
create trigger modoo_expenses_touch before update on public.modoo_expenses
  for each row execute function private.modoo_expenses_touch();

drop trigger if exists modoo_ai_solutions_touch on public.modoo_ai_solutions;
create trigger modoo_ai_solutions_touch before update on public.modoo_ai_solutions
  for each row execute function private.modoo_ai_solutions_touch();

drop trigger if exists modoo_ai_notes_touch on public.modoo_ai_notes;
create trigger modoo_ai_notes_touch before update on public.modoo_ai_notes
  for each row execute function private.modoo_ai_notes_touch();

-- ── 5. 증빙 파일 저장소 · 비공개 · 경로 modoo/{expense_id}/{uuid}.{확장자} ──
-- receipts 버킷과 섞지 않습니다. 서명 주소는 열 때마다 받고 표에 저장하지 않습니다.
insert into storage.buckets (id, name, public)
values ('modoo-evidence', 'modoo-evidence', false)
on conflict (id) do update set public = false;

do $blk$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and (coalesce(qual, '') like '%modoo-evidence%'
         or coalesce(with_check, '') like '%modoo-evidence%')
  loop
    execute format('drop policy if exists %I on storage.objects', policy_record.policyname);
  end loop;
end
$blk$;

create policy "모두의창업 증빙 조회" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'modoo-evidence'
    and ((select public.is_active_member()) or (select public.is_active_admin()))
  );

create policy "모두의창업 증빙 등록" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'modoo-evidence'
    and (storage.foldername(name))[1] = 'modoo'
    and ((select public.is_active_member()) or (select public.is_active_admin()))
  );

create policy "모두의창업 증빙 삭제" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'modoo-evidence'
    and ((select public.is_modoo_manager()) or (select public.is_active_admin()))
  );

-- ── 6. 「함께 쓰기」 · 로그인한 조합원 본인 이름만 users 칸에 더한다 ──
-- 표의 다른 칸(상태·사용료)은 건드리지 않는다. 이미 들어 있으면 그대로 둔다.
create or replace function public.modoo_join_solution(p_solution_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name  text;
  v_users text;
begin
  select display_name into v_name
    from public.member_accounts
   where user_id = auth.uid() and is_active = true
   limit 1;

  if v_name is null then
    raise exception 'not an active member';
  end if;

  select users into v_users
    from public.modoo_ai_solutions
   where id = p_solution_id and status <> '안 하기로 함'
   for update;

  if not found then
    raise exception 'solution not found';
  end if;

  if v_name = any (select btrim(x) from unnest(string_to_array(coalesce(v_users, ''), ',')) as x) then
    return v_users;
  end if;

  v_users := case when coalesce(btrim(v_users), '') = '' then v_name
                  else v_users || ', ' || v_name end;

  update public.modoo_ai_solutions set users = v_users where id = p_solution_id;
  return v_users;
end;
$$;

revoke all on function public.modoo_join_solution(uuid) from public, anon;
grant execute on function public.modoo_join_solution(uuid) to authenticated;

commit;

-- ── 7. 진단 · 한 표로 (SQL Editor 는 마지막 결과만 보여 줍니다) ──
select '표 있음 · modoo_managers' as 확인, (to_regclass('public.modoo_managers') is not null)::text as 값,
       (to_regclass('public.modoo_managers') is not null) as ok
union all
select '표 있음 · modoo_expenses', (to_regclass('public.modoo_expenses') is not null)::text,
       (to_regclass('public.modoo_expenses') is not null)
union all
select '표 있음 · modoo_ai_solutions', (to_regclass('public.modoo_ai_solutions') is not null)::text,
       (to_regclass('public.modoo_ai_solutions') is not null)
union all
select '표 있음 · modoo_ai_notes', (to_regclass('public.modoo_ai_notes') is not null)::text,
       (to_regclass('public.modoo_ai_notes') is not null)
union all
select 'RLS 켜진 표 수 (4)', count(*)::text, count(*) = 4
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('modoo_managers','modoo_expenses','modoo_ai_solutions','modoo_ai_notes')
   and c.relrowsecurity
union all
select 'anon 표 권한 (0)', count(*)::text, count(*) = 0
  from information_schema.role_table_grants
 where grantee = 'anon' and table_schema = 'public'
   and table_name in ('modoo_managers','modoo_expenses','modoo_ai_solutions','modoo_ai_notes')
union all
select 'anon 함수 실행 · is_modoo_manager (false)',
       has_function_privilege('anon', 'public.is_modoo_manager()', 'execute')::text,
       not has_function_privilege('anon', 'public.is_modoo_manager()', 'execute')
union all
select 'anon 함수 실행 · modoo_join_solution (false)',
       has_function_privilege('anon', 'public.modoo_join_solution(uuid)', 'execute')::text,
       not has_function_privilege('anon', 'public.modoo_join_solution(uuid)', 'execute')
union all
select '버킷 modoo-evidence 비공개', coalesce((select public::text from storage.buckets where id = 'modoo-evidence'), '없음'),
       coalesce((select not public from storage.buckets where id = 'modoo-evidence'), false)
union all
select '정책 수 · modoo_managers (1)', count(*)::text, count(*) = 1
  from pg_policies where schemaname = 'public' and tablename = 'modoo_managers'
union all
select '정책 수 · modoo_expenses (4)', count(*)::text, count(*) = 4
  from pg_policies where schemaname = 'public' and tablename = 'modoo_expenses'
union all
select '정책 수 · modoo_ai_solutions (4)', count(*)::text, count(*) = 4
  from pg_policies where schemaname = 'public' and tablename = 'modoo_ai_solutions'
union all
select '정책 수 · modoo_ai_notes (4)', count(*)::text, count(*) = 4
  from pg_policies where schemaname = 'public' and tablename = 'modoo_ai_notes'
union all
select '정책 수 · 증빙 저장소 (3)', count(*)::text, count(*) = 3
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and (coalesce(qual, '') like '%modoo-evidence%' or coalesce(with_check, '') like '%modoo-evidence%')
union all
select '관리 담당 (3명 · 활성 조합원)',
       count(*)::text || '명 · ' || coalesce(string_agg(m.display_name, ', ' order by m.display_name), ''),
       count(*) = 3
  from public.modoo_managers m
  join public.member_accounts a on a.user_id = m.user_id and a.is_active = true;
