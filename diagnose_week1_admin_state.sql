-- [1-4] 관리자 권한 작업 전 읽기 전용 점검.
-- 아무것도 만들거나 바꾸지 않습니다. 결과가 표 하나로 나옵니다.

select '1. 트리님 계정 user_id' as 항목,
       coalesce((select u.id::text from auth.users u
                  where lower(u.email) = 'simjimind@gmail.com'), '없음') as 결과
union all
select '2. 트리님 이메일인증',
       coalesce((select (u.email_confirmed_at is not null)::text from auth.users u
                  where lower(u.email) = 'simjimind@gmail.com'), '계정없음')
union all
select '3. 트리님 조합원활성',
       coalesce((select m.is_active::text
                   from public.member_accounts m
                   join auth.users u on u.id = m.user_id
                  where lower(u.email) = 'simjimind@gmail.com'), '연결안됨')
union all
select '4. 관리자 관련 테이블',
       coalesce((select string_agg(table_schema || '.' || table_name, ', ')
                   from information_schema.tables
                  where table_schema in ('public', 'private')
                    and (table_name ilike '%admin%' or table_name ilike '%role%'
                      or table_name ilike '%permission%')), '없음')
union all
select '5. site_admins 이름',
       case when exists (select 1 from information_schema.tables
                          where table_schema = 'public' and table_name = 'site_admins')
            then '이미 사용중' else '비어있음' end
union all
select '6. 관리자 관련 함수',
       coalesce((select string_agg(n.nspname || '.' || p.proname, ', ')
                   from pg_proc p
                   join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname in ('public', 'private')
                    and p.proname ilike '%admin%'), '없음')
union all
select '7. 관리자 언급 RLS 정책',
       coalesce((select string_agg(tablename || ': ' || policyname, ', ')
                   from pg_policies
                  where schemaname in ('public', 'storage')
                    and (coalesce(qual, '') ilike '%admin%'
                      or coalesce(with_check, '') ilike '%admin%')), '없음')
union all
select '8. 명부에 체험도메인 섞임',
       (select count(*)::text from public.member_accounts
         where email ilike '%@adlermind.co.kr')
union all
select '9. 전체 계정 수', (select count(*)::text from auth.users)
order by 1;
