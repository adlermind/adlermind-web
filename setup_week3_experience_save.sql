-- [1-H] 체험 결과 저장 흐름에 필요한 칸을 더합니다.
-- 기존 표·정책·GRANT 는 건드리지 않습니다. 여러 번 실행해도 안전합니다.
--
-- 지도 구역(map_regions)과 표현 다듬기(result_edits)는 여기서 만들지 않습니다.
-- 지도는 [1-I] 이고, 안 쓸 칸을 미리 만들지 않습니다.

begin;

-- 저장 시점에 체험을 만난 자리를 이력으로 함께 남깁니다.
-- 되짚지 않고 베껴 담는 이유 — experience_records 는 experiences 에 외래키를 걸지 않습니다
-- (체험을 지워도 참여자의 기록은 남는 설계). 되짚을 대상이 사라질 수 있습니다.
-- check 제약을 걸지 않는 이유 — 나중에 노출 자리 하나를 빼는 날,
-- 그 값이 적힌 옛 기록이 손댈 수 없는 줄이 됩니다.
alter table public.experience_records add column if not exists placement text;

-- 문항이나 해석을 고쳤을 때 옛 기록이 새 해석표로 읽히는 것을 막습니다.
alter table public.experience_records add column if not exists experience_version integer;

-- 체험 자료의 판 번호. 관리자 화면이 아니라 DB 가 올립니다.
-- 화면에 맡기면 잊고, SQL 로 직접 고치는 날엔 아예 안 올라갑니다.
alter table public.experiences add column if not exists version integer not null default 1;

-- ⚠ 이미 있는 touch_experiences() 에 가지를 더하지 않고 전용 함수로 분리합니다.
--    심지에서 공용 함수에 가지를 더했다가 그 함수를 함께 쓰던 체험후기가 죽은 사고가
--    있었습니다 (LOG_AND_FIX 2026-07-25). 판 번호는 experiences 만의 일입니다.
create or replace function public.bump_experience_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.body_html is distinct from old.body_html
     or new.link_url is distinct from old.link_url then
    new.version = coalesce(old.version, 1) + 1;
  end if;
  return new;
end;
$$;

drop trigger if exists experiences_bump_version on public.experiences;
create trigger experiences_bump_version
  before update on public.experiences
  for each row execute function public.bump_experience_version();

commit;

-- ── 진단 ────────────────────────────────────────────────────────
-- 아래 표의 passed 가 모두 true 여야 합니다.
-- Supabase SQL Editor 는 여러 문장을 실행하면 마지막 결과만 보여주므로 한 표로 모읍니다.
select '1. experience_records.placement 칸' as item,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experience_records'
                  and column_name = 'placement') as passed
union all
select '2. experience_records.experience_version 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experience_records'
                  and column_name = 'experience_version')
union all
select '3. experiences.version 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experiences'
                  and column_name = 'version')
union all
select '4. 판 번호 전용 트리거가 붙었다',
       exists (select 1 from pg_trigger
                where tgname = 'experiences_bump_version' and not tgisinternal)
union all
select '5. 기존 updated_at 트리거는 그대로다',
       exists (select 1 from pg_trigger
                where tgname = 'experiences_touch' and not tgisinternal)
union all
select '6. 본인 생성 정책이 그대로다',
       exists (select 1 from pg_policies
                where schemaname = 'public' and tablename = 'experience_records'
                  and policyname = '체험 기록 본인 생성')
 order by item;
