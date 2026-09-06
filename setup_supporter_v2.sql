-- ADLER MIND 협동조합 · 후원회원을 "정식계정 위에 얹는 자격"으로 전환 (2026-09-06)
-- 실행 위치 · Supabase jboceiacgczkqkhqcmqu > SQL Editor
-- 실행 주체 · 트리님이 직접 실행합니다.
--
-- 바뀌는 것
--  1) am_supporters 에 user_id 칸을 더해 auth.users 계정과 잇습니다.
--  2) 후원 신청은 로그인한 본인만 넣을 수 있게 바꿉니다. (anon 넣기 정책 제거)
--  3) 로그인한 본인이 자기 후원 상태를 조회할 수 있게 합니다. (본인 행만)
--  4) is_active_supporter() — 조합원 판정 is_active_member() 과 같은 형태의 후원회원 판정 함수.
--  5) admin_list_accounts() 에 후원 여부·상태 두 칸을 더합니다.
--
-- 기존에 로그인 없이 들어온 신청 행(user_id 가 비어 있음)은 그대로 남습니다.
-- 그 분들은 관리자가 Supabase Table Editor 에서 직접 확인·처리합니다.

begin;

-- 1) 계정 연결 칸 --------------------------------------------------------------
alter table public.am_supporters
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists am_supporters_user_id_idx on public.am_supporters(user_id);

-- 2) 넣기 정책 · 로그인 회원이 본인 이름으로만 -------------------------------
--   기존 anon 넣기 정책은 제거합니다. 이제 후원 신청은 회원가입·로그인을 거칩니다.
drop policy if exists "누구나 후원회원 신청을 넣습니다" on public.am_supporters;
revoke insert on public.am_supporters from anon;

grant insert on public.am_supporters to authenticated;
drop policy if exists "로그인 회원이 본인 후원 신청을 넣습니다" on public.am_supporters;
create policy "로그인 회원이 본인 후원 신청을 넣습니다"
  on public.am_supporters for insert to authenticated
  with check (user_id = (select auth.uid()));

-- 3) 조회 정책 · 본인 행만 --------------------------------------------------
grant select on public.am_supporters to authenticated;
drop policy if exists "본인 후원 상태 조회" on public.am_supporters;
create policy "본인 후원 상태 조회"
  on public.am_supporters for select to authenticated
  using (user_id = (select auth.uid()));

-- 4) 후원회원 판정 함수 ---------------------------------------------------------
create or replace function public.is_active_supporter()
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.am_supporters
     where user_id = (select auth.uid())
       and status = 'active'
  );
$$;

revoke all on function public.is_active_supporter() from public, anon;
grant execute on function public.is_active_supporter() to authenticated;

-- 5) 관리자 계정 목록에 후원 여부·상태 두 칸 추가 ----------------------------
--   반환 칸 구성이 바뀌므로 먼저 지우고 다시 만듭니다.
drop function if exists public.admin_list_accounts();

create function public.admin_list_accounts()
returns table (
  user_id          uuid,
  base_type        text,
  display_name     text,
  nickname         text,
  email            text,
  is_member        boolean,
  is_admin         boolean,
  is_supporter     boolean,
  supporter_status text,
  created_at       timestamptz,
  record_count     bigint,
  last_record_at   timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth_user.id,
    case when experience_user.user_id is not null then 'experience' else 'formal' end,
    profile.display_name,
    coalesce(profile.nickname, experience_user.nickname),
    case when experience_user.user_id is not null then null else auth_user.email end,
    coalesce(member.is_active, false),
    coalesce(admin.is_active, false),
    coalesce(supporter.status = 'active', false),
    supporter.status,
    auth_user.created_at,
    coalesce(records.record_count, 0),
    records.last_record_at
  from auth.users as auth_user
  left join public.site_users      as experience_user on experience_user.user_id = auth_user.id
  left join public.site_profiles   as profile         on profile.user_id         = auth_user.id
  left join public.member_accounts as member          on member.user_id          = auth_user.id
  left join public.site_admins     as admin           on admin.user_id           = auth_user.id
  left join lateral (
    -- 한 계정에 신청 행이 여럿일 수 있으므로 active 를 먼저, 그다음 최신 신청을 택합니다.
    select s.status
      from public.am_supporters as s
     where s.user_id = auth_user.id
     order by (s.status = 'active') desc, s.joined_at desc
     limit 1
  ) as supporter on true
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

-- 확인용 ---------------------------------------------------------------------
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'am_supporters'
 order by ordinal_position;

select p.proname, pg_get_function_result(p.oid) as returns
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('is_active_supporter', 'admin_list_accounts');
