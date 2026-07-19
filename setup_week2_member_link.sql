-- [2-6] 조합원 명부 등록 문제 고치기 — 반대 방향 트리거 추가
--
-- 기존 private.sync_formal_account() 트리거는 auth.users가 바뀔 때만 발화하므로
-- "명부 먼저 → 가입 나중" 순서만 이어준다.
-- 이 파일은 그 반대인 "가입 먼저 → 명부 나중" 순서를 이어주는 트리거를 얹는다.
-- 기존 함수·트리거·is_active_member()·site_admins는 건드리지 않는다.
--
-- 판정 근거는 변함없이 member_accounts.user_id + is_active이다.
-- 이 트리거는 판정 방식을 바꾸지 않고, 판정에 쓰이는 user_id가 비어 있던 구멍만 메운다.

begin;

create schema if not exists private;

create or replace function private.bind_member_account()
returns trigger
language plpgsql
security definer          -- auth.users를 읽어야 하므로 필요
set search_path = ''      -- 기존 sync_formal_account()와 동일한 안전 설정
as $$
declare
  candidate uuid;
begin
  -- 1. 이메일을 소문자로 정규화한다.
  --    member_accounts에 email = lower(email) 제약이 걸려 있어,
  --    대문자로 명부에 넣으면 연결 이전에 INSERT 자체가 거부된다.
  --    여기서 미리 다듬어 두면 대문자·앞뒤 공백으로 넣어도 정상 등록되고 연결까지 된다.
  new.email := lower(btrim(new.email));

  -- 2. 계정번호가 이미 채워져 있으면 절대 손대지 않는다.
  --    UPDATE로 관리자가 일부러 연결을 끊은 경우(old에 값이 있었는데 new가 비었음)도
  --    그 의도를 존중해 다시 채우지 않는다.
  if new.user_id is not null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.user_id is not null then
    return new;
  end if;

  -- 3. 이메일 인증을 마친 정식 이메일 계정 중에서 짝을 찾는다.
  --    조건은 기존 트리거와 대칭으로 맞췄다.
  --    account_type은 사용자가 고칠 수 있는 값이지만, 여기서는 권한 판정이 아니라
  --    짝 찾기에만 쓰이고 실제 관문은 관리자가 명부에 넣은 이메일과의 일치이므로 권한이 새지 않는다.
  --    체험계정은 내부 이메일을 쓰므로 실제 명부 이메일과 애초에 일치하지 않는다.
  select auth_user.id
    into candidate
    from auth.users as auth_user
   where lower(btrim(auth_user.email)) = new.email
     and auth_user.email_confirmed_at is not null
     and auth_user.raw_user_meta_data ->> 'account_type' = 'formal'
   order by auth_user.created_at
   limit 1;

  if candidate is null then
    -- 아직 가입하지 않은 분이다. 오류를 내지 않고 빈 채로 둔다.
    -- 그분이 나중에 가입하면 기존 트리거가 그때 채운다.
    return new;
  end if;

  -- 4. member_accounts.user_id에는 UNIQUE 제약이 있다.
  --    그 계정이 이미 다른 명부 줄에 쓰이고 있으면 채우지 않는다.
  --    (채우면 INSERT가 통째로 실패해 명부 등록 자체가 막힌다)
  if exists (
    select 1
      from public.member_accounts as other
     where other.user_id = candidate
       and other.email <> new.email
  ) then
    return new;
  end if;

  -- 5. is_active는 조건에 넣지 않는다.
  --    계정번호를 채우는 것만으로는 조합원 마당이 열리지 않으며,
  --    문은 is_active = true까지 갖춰져야 열린다(is_active_member()).
  --    비활성 줄에도 미리 채워두면 나중에 활성으로 바꾸는 순간 곧바로 열린다.
  new.user_id := candidate;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.bind_member_account() from public, anon, authenticated;

drop trigger if exists bind_member_account_before_write on public.member_accounts;
create trigger bind_member_account_before_write
before insert or update of email, user_id, is_active on public.member_accounts
for each row execute function private.bind_member_account();

commit;

-- 실행 후 확인용 읽기 쿼리. 트리거가 두 개(auth.users · member_accounts) 보여야 한다.
select tgname::text as 트리거이름,
       tgrelid::regclass::text as 붙은테이블,
       tgenabled::text as 켜짐상태
  from pg_trigger
 where not tgisinternal
   and tgrelid in ('auth.users'::regclass, 'public.member_accounts'::regclass)
 order by tgrelid::regclass::text, tgname;
