-- [1-I] 자기탐색 지도 — 구역 칸·스냅숏·표현 다듬기
-- 실행 위치: 아들러마인드 Supabase(jboceiacgczkqkhqcmqu) SQL Editor
-- 선행: setup_week2_experiences.sql · setup_week1_experience_records.sql · setup_week3_experience_save.sql
-- 여러 번 실행해도 안전합니다. 프로덕션 실행은 트리님이 직접 합니다.

begin;

-- ── 1. 체험 원본의 지도 구역 (관리자가 지정) ──────────────────
-- placement 는 홈페이지 노출 위치입니다. 지도 구역과 섞지 않습니다.
alter table public.experiences
  add column if not exists map_regions text[] not null default '{}'::text[];

alter table public.experiences
  drop constraint if exists experiences_map_regions_check;

alter table public.experiences
  add constraint experiences_map_regions_check
  check (
    map_regions <@ array[
      'bitteul',
      'ppurisaem',
      'baramgogae',
      'eoulsup',
      'sumgyeolgil',
      'maeumjari'
    ]::text[]
  );

comment on column public.experiences.map_regions is
  '관리자가 지정한 자기탐색 지도 구역 목록. 홈페이지 노출 위치인 placement 와 별도다.';

-- 옛 단수 칸은 지우지 않고 쓰지 않는다는 것만 남깁니다. 값이 비어 있어 옮길 것이 없습니다.
comment on column public.experiences.map_region is
  '사용하지 않는다. 단일값이라 다중 지도 구역에 맞지 않으며 map_regions 가 정본이다.';

-- ── 2. 저장 기록의 당시 구역과 참여자 수정본 ───────────────────
alter table public.experience_records
  add column if not exists map_regions text[] not null default '{}'::text[];

alter table public.experience_records
  add column if not exists result_edits jsonb not null default '{}'::jsonb;

alter table public.experience_records
  drop constraint if exists experience_records_result_edits_object_check;

alter table public.experience_records
  add constraint experience_records_result_edits_object_check
  check (jsonb_typeof(result_edits) = 'object');

comment on column public.experience_records.map_regions is
  '저장 시점의 experiences.map_regions 스냅숏. 이후 관리자가 배치를 바꿔도 옛 기록은 그대로다.';

comment on column public.experience_records.result_edits is
  '참여자가 다듬은 표현·뜻·작은 실천. 원문 result_data 는 덮어쓰지 않는다.';

-- 참여자가 표현을 다듬으면 고친 시각을 DB 가 적습니다.
-- ⚠ 이미 있는 함수에 가지를 더하지 않고 이 표만의 함수를 따로 만듭니다
--    (심지 2026-07-25 공용 함수 사고).
create or replace function public.touch_experience_records()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists experience_records_touch on public.experience_records;
create trigger experience_records_touch
  before update on public.experience_records
  for each row execute function public.touch_experience_records();

-- ── 3. 옛 기록 한 번 채우기 ────────────────────────────────────
-- 관리자가 구역을 지정한 뒤 이 파일을 한 번 더 실행하면 아직 비어 있는 옛 기록만 채웁니다.
-- ⚠ 배치를 바꿀 때마다 반복 실행하는 것이 아닙니다. 최초 이관용입니다.
update public.experience_records as record
   set map_regions = experience.map_regions
  from public.experiences as experience
 where record.experience_key = experience.experience_key
   and cardinality(record.map_regions) = 0
   and cardinality(experience.map_regions) > 0;

-- ── 4. 원문 보호 ───────────────────────────────────────────────
-- 지금은 UPDATE 가 통째로 열려 있어 참여자가 result_data·map_regions 까지 고칠 수 있습니다.
-- 고칠 수 있는 칸을 result_edits 하나로 좁힙니다. 기존 정책 4개는 건드리지 않습니다.
revoke update on public.experience_records from authenticated;
grant update (result_edits) on public.experience_records to authenticated;

commit;

-- ── 5. 한 표로 확인 ────────────────────────────────────────────
-- 모든 줄의 passed 가 true 여야 합니다.
select '1. experiences.map_regions 칸' as item,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experiences'
                  and column_name = 'map_regions' and data_type = 'ARRAY') as passed
union all
select '2. experience_records.map_regions 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experience_records'
                  and column_name = 'map_regions' and data_type = 'ARRAY')
union all
select '3. experience_records.result_edits 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experience_records'
                  and column_name = 'result_edits' and data_type = 'jsonb')
union all
select '4. 다듬은 표현은 고칠 수 있다',
       has_column_privilege('authenticated', 'public.experience_records', 'result_edits', 'UPDATE')
union all
select '5. 원문 결과는 고칠 수 없다',
       not has_column_privilege('authenticated', 'public.experience_records', 'result_data', 'UPDATE')
union all
select '6. 응답 원문도 고칠 수 없다',
       not has_column_privilege('authenticated', 'public.experience_records', 'response_data', 'UPDATE')
union all
select '7. 지도 구역 스냅숏도 고칠 수 없다',
       not has_column_privilege('authenticated', 'public.experience_records', 'map_regions', 'UPDATE')
union all
select '8. 기존 정책 4개가 그대로다',
       (select count(*) = 4 from pg_policies
         where schemaname = 'public' and tablename = 'experience_records')
union all
select '9. 수정 시각 트리거가 붙었다',
       exists (select 1 from pg_trigger
                where tgname = 'experience_records_touch' and not tgisinternal)
 order by item;
