-- [2-6] 조합원 명부 등록 문제 · 고치기 전 현재 상태 진단
-- 읽기 전용입니다. 이 파일은 아무것도 만들거나 고치거나 지우지 않습니다.
-- Supabase SQL Editor는 마지막 결과 하나만 보여주므로, 모든 점검을 한 표로 모았습니다.
-- 통째로 붙여넣고 Run 하면 결과가 한 개 표로 나옵니다.

-- A. 명부 요약
select 10 as 순서, 'A. 명부 요약' as 구분, '전체 줄 수' as 항목, count(*)::text as 값
  from public.member_accounts
union all
select 11, 'A. 명부 요약', '활성 (스위치 켜짐)', (count(*) filter (where is_active))::text
  from public.member_accounts
union all
select 12, 'A. 명부 요약', '활성 + 계정번호 채워짐 (정상)', (count(*) filter (where is_active and user_id is not null))::text
  from public.member_accounts
union all
select 13, 'A. 명부 요약', '활성인데 계정번호 비어 있음 (핵심 지표)', (count(*) filter (where is_active and user_id is null))::text
  from public.member_accounts
union all
select 14, 'A. 명부 요약', '비활성 (스위치 꺼짐)', (count(*) filter (where not is_active))::text
  from public.member_accounts

-- B. 계정번호 칸이 빈 줄 — 개수 먼저, 그 다음 목록
union all
select 20, 'B. 계정번호 빈 줄', '개수', count(*)::text
  from public.member_accounts where user_id is null
union all
select 21, 'B. 계정번호 빈 줄',
       member.display_name || ' / ' || (case when member.is_active then '활성' else '비활성' end),
       case when auth_user.id is not null
            then '연결가능 — 이번에 고칠 대상'
            else '짝이 되는 가입계정 아직 없음'
       end
  from public.member_accounts as member
  left join auth.users as auth_user
         on lower(btrim(auth_user.email)) = member.email
        and auth_user.email_confirmed_at is not null
        and auth_user.raw_user_meta_data ->> 'account_type' = 'formal'
 where member.user_id is null

-- C. 이미 연결된 줄 — 이번 작업으로 바뀌면 안 되는 줄
union all
select 30, 'C. 이미 연결된 줄', '개수 (작업 후에도 같아야 함)', count(*)::text
  from public.member_accounts where user_id is not null
union all
select 31, 'C. 이미 연결된 줄',
       display_name || ' / ' || (case when is_active then '활성' else '비활성' end),
       '계정번호 뒤 6자리 ' || right(user_id::text, 6)
  from public.member_accounts where user_id is not null

-- D. 이메일에 앞뒤 공백이 섞였는지 (짝 찾기를 방해함)
union all
select 40, 'D. 이메일 형태', '공백·대문자 섞인 줄 개수 (0이어야 정상)', count(*)::text
  from public.member_accounts where email <> lower(btrim(email))

-- E. 기존 트리거 — 이번 작업은 건드리지 않으므로 작업 후에도 그대로여야 함
union all
select 50, 'E. 기존 트리거', tgname::text, tgrelid::regclass::text || ' / 켜짐상태 ' || tgenabled::text
  from pg_trigger
 where not tgisinternal
   and tgrelid in ('auth.users'::regclass, 'public.member_accounts'::regclass)

order by 순서, 항목;
