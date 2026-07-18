-- [1-4] 관리자 권한 계층을 만듭니다.
-- 조합원 권한(member_accounts · is_active_member)과 별도 계층이며, 기존 구조는 건드리지 않습니다.
-- 검증된 member_accounts 패턴을 그대로 복제했습니다.

begin;

-- 관리자 명부. 권한 부여·회수는 이 테이블에서만 하며 브라우저에서는 수정할 수 없습니다.
create table if not exists public.site_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.site_admins enable row level security;
revoke all on public.site_admins from anon;
revoke all on public.site_admins from authenticated;
grant usage on schema public to authenticated;
grant select on public.site_admins to authenticated;

-- 본인의 활성 관리자 행 한 줄만 조회할 수 있습니다. INSERT·UPDATE·DELETE 정책은 두지 않습니다.
drop policy if exists "관리자 본인 권한 조회" on public.site_admins;
create policy "관리자 본인 권한 조회" on public.site_admins
  for select to authenticated
  using (user_id = (select auth.uid()) and is_active = true);

-- 관리자 판정 함수. is_active_member()와 같은 형태입니다.
create or replace function public.is_active_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.site_admins
     where user_id = (select auth.uid())
       and is_active = true
  );
$$;

revoke all on function public.is_active_admin() from public, anon;
grant execute on function public.is_active_admin() to authenticated;

-- 트리님 계정에만 관리자 권한을 부여합니다. 이메일이 아니라 계정 고유번호로 지정합니다.
insert into public.site_admins (user_id)
values ('584d15f7-9955-45d7-b35d-8b6e4c45186c')
on conflict (user_id) do update
  set is_active = true,
      updated_at = now();

commit;

-- 실행 후 확인용 읽기 쿼리.
select a.user_id, u.email, a.is_active, a.created_at
  from public.site_admins a
  join auth.users u on u.id = a.user_id
 order by a.created_at;
