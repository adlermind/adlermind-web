-- 체험 응답·피드백과 별칭 공개 후기를 저장하고 사용자·관리자·공개 접근을 분리합니다.

begin;

-- 질문별 응답, 결과와 운영 피드백을 한 건의 체험 기록으로 보관합니다.
create table if not exists public.experience_records (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  experience_key  text not null,
  experience_title text not null,
  context_type    text not null default 'experience'
                  check (context_type in ('experience', 'program')),
  context_id      text,
  response_data   jsonb not null default '{}'::jsonb,
  result_data     jsonb not null default '{}'::jsonb,
  feedback_rating smallint check (feedback_rating between 1 and 5),
  feedback_text   text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists experience_records_user_created_idx
  on public.experience_records (user_id, created_at desc);
create index if not exists experience_records_experience_created_idx
  on public.experience_records (experience_key, created_at desc);

alter table public.experience_records enable row level security;
revoke all on public.experience_records from anon;
revoke all on public.experience_records from authenticated;
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.experience_records to authenticated;

drop policy if exists "체험 기록 본인과 관리자 조회" on public.experience_records;
create policy "체험 기록 본인과 관리자 조회" on public.experience_records
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_active_admin())
  );

drop policy if exists "체험 기록 본인 생성" on public.experience_records;
create policy "체험 기록 본인 생성" on public.experience_records
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "체험 기록 본인 수정" on public.experience_records;
create policy "체험 기록 본인 수정" on public.experience_records
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "체험 기록 본인 삭제" on public.experience_records;
create policy "체험 기록 본인 삭제" on public.experience_records
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- 사용자가 공개를 선택한 후기만 별도 보관합니다. 공개 화면에는 이 테이블만 연결합니다.
create table if not exists public.experience_reviews (
  id                uuid primary key default gen_random_uuid(),
  record_id         uuid not null references public.experience_records(id) on delete cascade,
  user_id           uuid not null references auth.users(id) on delete cascade,
  experience_key    text not null,
  experience_title  text not null,
  public_alias      text not null check (char_length(btrim(public_alias)) between 1 and 30),
  review_text       text not null check (char_length(btrim(review_text)) between 1 and 2000),
  is_public         boolean not null default true,
  is_hidden         boolean not null default false,
  created_at        timestamptz not null default now(),
  hidden_at         timestamptz
);

create unique index if not exists experience_reviews_record_unique
  on public.experience_reviews (record_id);
create index if not exists experience_reviews_public_created_idx
  on public.experience_reviews (created_at desc)
  where is_public = true and is_hidden = false;

alter table public.experience_reviews enable row level security;
revoke all on public.experience_reviews from anon;
revoke all on public.experience_reviews from authenticated;
grant usage on schema public to anon, authenticated;
grant select (
  id, experience_key, experience_title, public_alias,
  review_text, is_public, is_hidden, created_at, hidden_at
) on public.experience_reviews to anon, authenticated;
grant insert, delete on public.experience_reviews to authenticated;
grant update on public.experience_reviews to authenticated;

drop policy if exists "공개 후기 누구나 조회" on public.experience_reviews;
create policy "공개 후기 누구나 조회" on public.experience_reviews
  for select to anon, authenticated
  using (is_public = true and is_hidden = false);

drop policy if exists "공개 후기 본인과 관리자 조회" on public.experience_reviews;
create policy "공개 후기 본인과 관리자 조회" on public.experience_reviews
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_active_admin())
  );

drop policy if exists "공개 후기 본인 생성" on public.experience_reviews;
create policy "공개 후기 본인 생성" on public.experience_reviews
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and is_public = true
    and is_hidden = false
    and hidden_at is null
    and exists (
      select 1
        from public.experience_records r
       where r.id = record_id
         and r.user_id = (select auth.uid())
    )
  );

drop policy if exists "공개 후기 본인 철회" on public.experience_reviews;
create policy "공개 후기 본인 철회" on public.experience_reviews
  for delete to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "공개 후기 관리자 숨김" on public.experience_reviews;
create policy "공개 후기 관리자 숨김" on public.experience_reviews
  for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));

commit;

-- SQL Editor 실행 직후 구조 확인용 읽기 쿼리입니다.
select c.relname as table_name, c.relrowsecurity as row_security
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('experience_records', 'experience_reviews')
 order by c.relname;

select schemaname, tablename, policyname, roles, cmd
  from pg_policies
 where schemaname = 'public'
   and tablename in ('experience_records', 'experience_reviews')
 order by tablename, policyname;
