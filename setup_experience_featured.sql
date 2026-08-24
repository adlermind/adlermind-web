-- [체험 앞자리] 대문 맨 앞에 걸 체험을 체크 하나로 고릅니다 (2026-08-24).
-- 순서 숫자를 매기는 대신 체크한 체험이 대문 앞줄에 섭니다.
-- 체크하지 않은 체험도 그 뒤에 이어서 그대로 나옵니다 — 대문에서 사라지지 않습니다.
-- 기존 표·정책·GRANT·트리거는 건드리지 않습니다. 여러 번 실행해도 안전합니다.

begin;

-- 참: 대문 앞줄. 거짓: 뒤에 이어서.
-- 방(상담·배움) 안 목록은 예전처럼 sort_order 만 따릅니다.
alter table public.experiences
  add column if not exists is_featured boolean not null default false;

-- 대문이 늘 쓰는 차례(앞자리 먼저 · 그다음 순서 숫자)로 찾도록 색인을 답니다.
create index if not exists experiences_featured_order_idx
  on public.experiences (is_featured desc, sort_order);

commit;

-- 판 번호(version) 트리거는 body_html 과 link_url 이 바뀔 때만 올라가므로
-- 앞자리 체크를 켜고 꺼도 참여자의 옛 기록 해석에는 영향이 없습니다.

-- ── 진단 ────────────────────────────────────────────────────────
-- 아래 표의 passed 가 모두 true 여야 합니다.
select '1. experiences.is_featured 칸' as item,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'experiences'
                  and column_name = 'is_featured') as passed
union all
select '2. 앞자리 색인이 붙었다',
       exists (select 1 from pg_indexes
                where schemaname = 'public' and tablename = 'experiences'
                  and indexname = 'experiences_featured_order_idx')
union all
select '3. 기존 updated_at 트리거는 그대로다',
       exists (select 1 from pg_trigger
                where tgname = 'experiences_touch' and not tgisinternal)
union all
select '4. 기존 판 번호 트리거는 그대로다',
       exists (select 1 from pg_trigger
                where tgname = 'experiences_bump_version' and not tgisinternal)
union all
select '5. 체험 수정 정책이 그대로다',
       exists (select 1 from pg_policies
                where schemaname = 'public' and tablename = 'experiences'
                  and policyname = '체험 수정')
 order by item;
