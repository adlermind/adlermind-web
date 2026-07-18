-- 활성 조합원 권한이 확인된 이메일 회원만 내부 데이터에 접근하도록 RLS를 전환합니다.
-- setup_week1_formal_accounts.sql 실행과 실제 로그인 검증을 마친 뒤 마지막에 실행합니다.

begin;

create table if not exists public.member_accounts (
  email        text primary key,
  display_name text not null,
  user_id      uuid unique references auth.users(id) on delete set null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint member_accounts_email_lowercase check (email = lower(email))
);

alter table public.member_accounts enable row level security;
revoke all on public.member_accounts from anon;
revoke all on public.member_accounts from authenticated;
grant usage on schema public to authenticated;
grant select on public.member_accounts to authenticated;

drop policy if exists "조합원 본인 계정 조회" on public.member_accounts;
create policy "조합원 본인 계정 조회" on public.member_accounts
  for select to authenticated
  using (user_id = (select auth.uid()) and is_active = true);

create or replace function public.is_active_member()
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
      from public.member_accounts
     where user_id = (select auth.uid())
       and is_active = true
  );
$$;

revoke all on function public.is_active_member() from public, anon;
grant execute on function public.is_active_member() to authenticated;

-- 내부 테이블의 anon 권한을 회수하고 authenticated 역할에 테이블 권한을 부여한다.
revoke all on public.board_comments from anon;
revoke all on public.am_meetings from anon;
revoke all on public.am_votes from anon;
revoke all on public.am_availability from anon;
revoke all on public.accounting_records from anon;
revoke all on public.am_ideas from anon;
revoke select, delete on public.contact_messages from anon;

grant select, insert, update, delete on public.board_posts to authenticated;
grant select, insert, update, delete on public.board_comments to authenticated;
grant select, insert, update, delete on public.am_meetings to authenticated;
grant select, insert, update, delete on public.am_votes to authenticated;
grant select, insert, update, delete on public.am_availability to authenticated;
grant select, insert, update, delete on public.accounting_records to authenticated;
grant select, insert, update, delete on public.am_ideas to authenticated;
grant select, delete on public.contact_messages to authenticated;

-- 공개 소식은 anon 읽기만 유지한다.
grant select on public.board_posts to anon;
alter table public.board_posts enable row level security;
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'public' and tablename = 'board_posts'
  loop
    execute format('drop policy if exists %I on public.board_posts', policy_record.policyname);
  end loop;
end
$$;
create policy "공개 게시글 조회" on public.board_posts
  for select to anon, authenticated using (visibility = 'public');
create policy "조합원 게시글 조회" on public.board_posts
  for select to authenticated using ((select public.is_active_member()));
create policy "조합원 게시글 등록" on public.board_posts
  for insert to authenticated with check ((select public.is_active_member()));
create policy "조합원 게시글 수정" on public.board_posts
  for update to authenticated
  using ((select public.is_active_member()))
  with check ((select public.is_active_member()));
create policy "조합원 게시글 삭제" on public.board_posts
  for delete to authenticated using ((select public.is_active_member()));

-- 조합원 내부 테이블은 활성 조합원만 CRUD를 허용한다.
do $$
declare
  table_name text;
  policy_record record;
begin
  foreach table_name in array array[
    'board_comments', 'am_meetings', 'am_votes', 'am_availability',
    'accounting_records', 'am_ideas'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    for policy_record in
      select policyname from pg_policies
       where schemaname = 'public' and tablename = table_name
    loop
      execute format('drop policy if exists %I on public.%I', policy_record.policyname, table_name);
    end loop;
    execute format('create policy "member_select" on public.%I for select to authenticated using ((select public.is_active_member()))', table_name);
    execute format('create policy "member_insert" on public.%I for insert to authenticated with check ((select public.is_active_member()))', table_name);
    execute format('create policy "member_update" on public.%I for update to authenticated using ((select public.is_active_member())) with check ((select public.is_active_member()))', table_name);
    execute format('create policy "member_delete" on public.%I for delete to authenticated using ((select public.is_active_member()))', table_name);
  end loop;
end
$$;

-- 문의 접수용 anon INSERT는 유지하고 조회·삭제 정책만 조합원용으로 교체한다.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'public'
       and tablename = 'contact_messages'
       and cmd in ('SELECT', 'DELETE')
  loop
    execute format('drop policy if exists %I on public.contact_messages', policy_record.policyname);
  end loop;
end
$$;

drop policy if exists "조합원 문의 조회" on public.contact_messages;
drop policy if exists "조합원 문의 삭제" on public.contact_messages;
create policy "조합원 문의 조회" on public.contact_messages
  for select to authenticated using ((select public.is_active_member()));
create policy "조합원 문의 삭제" on public.contact_messages
  for delete to authenticated using ((select public.is_active_member()));

-- 조합원 첨부파일 업로드·조회·수정·삭제를 활성 조합원으로 제한한다.
update storage.buckets set public = false where id in ('board-files', 'receipts');
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and (coalesce(qual, '') like '%board-files%'
         or coalesce(with_check, '') like '%board-files%'
         or coalesce(qual, '') like '%receipts%'
         or coalesce(with_check, '') like '%receipts%')
  loop
    execute format('drop policy if exists %I on storage.objects', policy_record.policyname);
  end loop;
end
$$;
create policy "조합원 board-files 조회" on storage.objects
  for select to authenticated
  using (bucket_id = 'board-files' and (select public.is_active_member()));
create policy "조합원 board-files 등록" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'board-files' and (select public.is_active_member()));
create policy "조합원 board-files 수정" on storage.objects
  for update to authenticated
  using (bucket_id = 'board-files' and (select public.is_active_member()))
  with check (bucket_id = 'board-files' and (select public.is_active_member()));
create policy "조합원 board-files 삭제" on storage.objects
  for delete to authenticated
  using (bucket_id = 'board-files' and (select public.is_active_member()));

create policy "조합원 receipts 조회" on storage.objects
  for select to authenticated
  using (bucket_id = 'receipts' and (select public.is_active_member()));
create policy "조합원 receipts 등록" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'receipts' and (select public.is_active_member()));
create policy "조합원 receipts 수정" on storage.objects
  for update to authenticated
  using (bucket_id = 'receipts' and (select public.is_active_member()))
  with check (bucket_id = 'receipts' and (select public.is_active_member()));
create policy "조합원 receipts 삭제" on storage.objects
  for delete to authenticated
  using (bucket_id = 'receipts' and (select public.is_active_member()));

commit;

-- 실행 후 확인용 읽기 쿼리.
select email, display_name, user_id, is_active from public.member_accounts order by display_name;
