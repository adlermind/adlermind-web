-- [2-1] 관리자 회원관리 탭이 쓰는 계정 목록 조회 함수입니다.
-- 테이블마다 관리자 조회 정책을 늘리지 않고, 관리자만 실행되는 함수 하나로 필요한 항목만 내보냅니다.
-- 이메일 회원의 이메일은 auth.users 에만 있어 REST 로 직접 열 수 없기 때문입니다.
-- 체험계정의 내부 이메일은 이 함수가 내보내지 않습니다. (기획서 4-2 원칙)
-- 기존 테이블과 정책은 건드리지 않습니다.

begin;

create or replace function public.admin_list_accounts()
returns table (
  user_id        uuid,
  base_type      text,
  display_name   text,
  nickname       text,
  email          text,
  is_member      boolean,
  is_admin       boolean,
  created_at     timestamptz,
  record_count   bigint,
  last_record_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth_user.id,
    -- 체험계정은 site_users 에 별칭 행이 있고, 이메일 회원은 없습니다.
    case when experience_user.user_id is not null then 'experience' else 'formal' end,
    profile.display_name,
    coalesce(profile.nickname, experience_user.nickname),
    -- 체험계정의 내부 이메일은 관리자에게도 표시하지 않습니다.
    case when experience_user.user_id is not null then null else auth_user.email end,
    coalesce(member.is_active, false),
    coalesce(admin.is_active, false),
    auth_user.created_at,
    coalesce(records.record_count, 0),
    records.last_record_at
  from auth.users as auth_user
  left join public.site_users     as experience_user on experience_user.user_id = auth_user.id
  left join public.site_profiles  as profile         on profile.user_id         = auth_user.id
  left join public.member_accounts as member         on member.user_id          = auth_user.id
  left join public.site_admins    as admin           on admin.user_id           = auth_user.id
  left join (
    select record.user_id,
           count(*)               as record_count,
           max(record.created_at) as last_record_at
      from public.experience_records as record
     group by record.user_id
  ) as records on records.user_id = auth_user.id
 where (select public.is_active_admin())
 order by auth_user.created_at desc;
$$;

revoke all on function public.admin_list_accounts() from public, anon;
grant execute on function public.admin_list_accounts() to authenticated;

commit;

-- 실행 직후 확인용 읽기 쿼리입니다. SQL Editor 에서는 관리자 판정이 걸리지 않으므로
-- 함수 존재 여부와 권한만 확인하고, 실제 결과는 admin.html 화면에서 확인합니다.
select p.proname, p.prosecdef as security_definer, pg_get_function_result(p.oid) as returns
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'admin_list_accounts';

select grantee, privilege_type
  from information_schema.routine_privileges
 where routine_schema = 'public'
   and routine_name = 'admin_list_accounts';
