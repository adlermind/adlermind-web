-- 문의 접수 상태(접수·배정·완료)와 담당자를 담습니다.
-- 실행 위치: 아들러마인드 Supabase(jboceiacgczkqkhqcmqu) SQL Editor
-- 선행: setup_contact.sql → migrate_week1_member_invite_auth.sql → setup_contact_fields.sql
-- 여러 번 실행해도 안전합니다. 프로덕션 실행은 트리님이 직접 합니다.
--
-- ⚠ 이 SQL 을 먼저 실행하고 members-home.html 을 올립니다.
--    순서를 바꾸면 표에 없는 칸을 보내 상태 바꾸기가 실패합니다.
--
-- 이 두 칸은 조합원 마당에서만 보입니다. 방문자 화면(contact.html)은 한 글자도 바뀌지 않습니다.

begin;

-- 처리 상태. 새 문의는 '접수'로 들어옵니다.
-- 옛 문의 줄에도 기본값이 함께 채워져 목록에서 빈칸으로 보이지 않습니다.
alter table public.contact_messages
  add column if not exists status text not null default '접수';

alter table public.contact_messages
  drop constraint if exists contact_messages_status_check;

alter table public.contact_messages
  add constraint contact_messages_status_check
  check (status in ('접수', '배정', '완료'));

-- 누가 맡았는지. 조합원 계정과 연결하지 않고 이름 글자만 담습니다 —
-- preferred_counselor 와 같은 판단입니다. 배정은 사람이 하고, 적는 이름도 사람이 고릅니다.
-- ⚠ 이 값은 조합원 마당 안에서만 보입니다. 방문자에게 담당자 이름을 알리지 않습니다(순차 배정).
alter table public.contact_messages
  add column if not exists assigned_to text;

comment on column public.contact_messages.status is
  '처리 상태. 접수 · 배정 · 완료. 조합원 마당에서만 보이며 방문자 화면에 나타나지 않는다.';
comment on column public.contact_messages.assigned_to is
  '배정된 담당자 이름. 조합원 마당 안에서만 보인다. 조합원 계정과 연결하지 않는다.';

-- 상태를 바꿀 권한을 이 두 칸으로만 좁힙니다.
-- 칸을 지정하지 않고 update 를 열면 방문자가 적어 보낸 이름·연락처·상담 내용까지 고칠 수 있게 됩니다.
grant update (status, assigned_to) on public.contact_messages to authenticated;

-- 조회·삭제 정책과 같은 조건을 씁니다(활성 조합원).
-- ⚠ is_active_admin() 을 더하지 않은 이유 — 지금 문의 조회 정책이 조합원만 보게 되어 있습니다.
--    관리자에게도 문의를 열어줄지는 별도 판단이라 이 SQL 에서 바꾸지 않습니다.
drop policy if exists "조합원 문의 상태 변경" on public.contact_messages;
create policy "조합원 문의 상태 변경" on public.contact_messages
  for update to authenticated
  using ((select public.is_active_member()))
  with check ((select public.is_active_member()));

commit;

-- ── 확인 ───────────────────────────────────────────────────────
-- 모든 줄의 passed 가 true 여야 합니다.
select '1. 처리 상태 칸' as item,
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'contact_messages'
                  and column_name = 'status') as passed
union all
select '2. 담당자 칸',
       exists (select 1 from information_schema.columns
                where table_schema = 'public' and table_name = 'contact_messages'
                  and column_name = 'assigned_to')
union all
select '3. 상태 값이 접수·배정·완료 셋으로 제한된다',
       exists (select 1 from pg_constraint
                where conname = 'contact_messages_status_check')
union all
select '4. 옛 문의에도 상태가 채워졌다 (빈칸 0줄)',
       not exists (select 1 from public.contact_messages where status is null)
union all
select '5. 조합원이 상태를 바꿀 수 있다 (정책)',
       exists (select 1 from pg_policies
                where schemaname = 'public' and tablename = 'contact_messages'
                  and cmd = 'UPDATE')
union all
select '6. 고칠 수 있는 칸이 status·assigned_to 둘뿐이다',
       (select count(*) from information_schema.column_privileges
         where table_schema = 'public' and table_name = 'contact_messages'
           and grantee = 'authenticated' and privilege_type = 'UPDATE') = 2
union all
select '7. 누구나 문의를 넣을 수 있다 (기존 정책 유지)',
       exists (select 1 from pg_policies
                where schemaname = 'public' and tablename = 'contact_messages'
                  and cmd = 'INSERT')
 order by item;
