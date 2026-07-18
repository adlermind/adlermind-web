-- 이메일 회원 프로필에 공개 표시용 별칭을 추가하고 인증 완료 시 함께 저장합니다.

begin;

alter table public.site_profiles
  add column if not exists nickname text;

update public.site_profiles
   set nickname = left(btrim(display_name), 20)
 where nickname is null;

alter table public.site_profiles
  alter column nickname set not null;

alter table public.site_profiles
  drop constraint if exists site_profiles_nickname_length;
alter table public.site_profiles
  add constraint site_profiles_nickname_length
  check (char_length(btrim(nickname)) between 2 and 20);

create or replace function private.sync_formal_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_type text := new.raw_user_meta_data ->> 'account_type';
  display_name text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  nickname text := btrim(coalesce(new.raw_user_meta_data ->> 'nickname', ''));
begin
  if new.email_confirmed_at is not null and account_type = 'formal' then
    if char_length(display_name) between 2 and 40
       and char_length(nickname) between 2 and 20 then
      insert into public.site_profiles (user_id, display_name, nickname)
      values (new.id, display_name, nickname)
      on conflict (user_id) do nothing;
    end if;

    update public.member_accounts
       set user_id = new.id,
           updated_at = now()
     where email = lower(new.email)
       and is_active = true
       and (user_id is null or user_id = new.id);
  end if;
  return new;
end;
$$;

revoke all on function private.sync_formal_account() from public, anon, authenticated;

commit;

select user_id, display_name, nickname, created_at
  from public.site_profiles
 order by created_at;
