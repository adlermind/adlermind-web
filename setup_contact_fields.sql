-- 문의 폼에 상담 배정에 필요한 칸을 더합니다.
-- 실행 위치: 아들러마인드 Supabase(jboceiacgczkqkhqcmqu) SQL Editor
-- 선행: setup_contact.sql
-- 여러 번 실행해도 안전합니다. 프로덕션 실행은 트리님이 직접 합니다.
--
-- 기존 칸(name·phone·email·category·message)은 건드리지 않습니다.
-- 옛 문의 줄에는 새 칸이 비어 있게 되며, 그대로 두는 것이 맞습니다.

begin;

-- 희망하시는 상담자. 비워두면 조합이 순차 배정합니다.
-- 이름 글자만 담습니다. 조합원 계정과 연결하지 않습니다 —
-- 방문자가 적는 값이라 오타·별칭이 들어올 수 있고, 배정은 사람이 판단합니다.
alter table public.contact_messages
  add column if not exists preferred_counselor text;

-- 온라인 상담 희망 여부. 'online' · 'offline' · 'either' 셋 중 하나이거나 비어 있습니다.
alter table public.contact_messages
  add column if not exists online_pref text;

alter table public.contact_messages
  drop constraint if exists contact_messages_online_pref_check;

alter table public.contact_messages
  add constraint contact_messages_online_pref_check
  check (online_pref is null or online_pref in ('online', 'offline', 'either'));

-- 상담이 가능한 시간. 요일·시간대를 자유롭게 적는 칸이라 글자로 받습니다.
-- 표로 쪼개지 않는 이유 — "평일 저녁, 토요일 오전은 어려움" 같은 말을 담아야 합니다.
alter table public.contact_messages
  add column if not exists available_time text;

-- 홈페이지 어느 자리에서 문의를 눌렀는지. 방문자가 고르는 값이 아니라 화면이 담습니다.
-- 문의유형(category)과 다릅니다 — 유형은 방문자가 직접 고릅니다.
alter table public.contact_messages
  add column if not exists source_page text;

comment on column public.contact_messages.preferred_counselor is
  '방문자가 희망한 상담자 이름. 비어 있으면 조합이 순차 배정한다.';
comment on column public.contact_messages.online_pref is
  '온라인 상담 희망. online · offline · either.';
comment on column public.contact_messages.available_time is
  '상담이 가능한 요일·시간대. 자유롭게 적는 글이다.';
comment on column public.contact_messages.source_page is
  '문의를 누른 자리(예: 상담의 방 · 매체상담). 화면이 담으며 방문자가 고르지 않는다.';

commit;

-- ── 확인 ───────────────────────────────────────────────────────
-- 모든 줄의 passed 가 true 여야 합니다.
select '1. 희망 상담자 칸' as item,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'contact_messages'
                  and column_name = 'preferred_counselor') as passed
union all
select '2. 온라인 희망 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'contact_messages'
                  and column_name = 'online_pref')
union all
select '3. 가능 시간 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'contact_messages'
                  and column_name = 'available_time')
union all
select '4. 문의한 자리 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'contact_messages'
                  and column_name = 'source_page')
union all
select '5. 온라인 희망 값 제한이 걸렸다',
       exists (select 1 from pg_constraint
                where conname = 'contact_messages_online_pref_check')
union all
select '6. 누구나 문의를 넣을 수 있다 (기존 정책 유지)',
       exists (select 1 from pg_policies
                where schemaname = 'public' and tablename = 'contact_messages'
                  and cmd = 'INSERT')
 order by item;
