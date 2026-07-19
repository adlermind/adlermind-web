-- 체험 기록과 공개 후기 RLS를 운영 데이터 변경 없이 검증합니다.

begin;

create temporary table week1_test_users (
  label text primary key,
  user_id uuid not null
) on commit drop;

create temporary table week1_test_results (
  check_no integer primary key,
  check_name text not null,
  expected text not null,
  actual text not null,
  passed boolean not null
) on commit drop;

insert into week1_test_users (label, user_id)
select 'admin', user_id
  from public.site_admins
 where is_active = true
 order by created_at
 limit 1;

insert into week1_test_users (label, user_id)
select 'owner', u.id
  from auth.users u
 where not exists (
   select 1 from public.site_admins a
    where a.user_id = u.id and a.is_active = true
 )
 order by u.created_at desc
 limit 1;

do $$
begin
  if (select count(*) from week1_test_users) <> 2 then
    raise exception '활성 관리자와 비관리자 테스트 계정이 각각 1개 이상 필요합니다.';
  end if;
end;
$$;

grant select on week1_test_users to authenticated;
grant select, insert on week1_test_results to anon, authenticated;

-- 비관리자 본인으로 체험 기록과 공개 후기를 생성합니다.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from week1_test_users where label = 'owner'),
  true
);

insert into public.experience_records (
  user_id, experience_key, experience_title,
  response_data, result_data, feedback_rating, feedback_text
)
values (
  (select user_id from week1_test_users where label = 'owner'),
  '__week1_rls_test__',
  '1주차 RLS 검증용 체험',
  '{"answer":"검증 응답"}'::jsonb,
  '{"result":"검증 결과"}'::jsonb,
  5,
  '검증 피드백'
);

insert into public.experience_reviews (
  record_id, user_id, experience_key, experience_title,
  public_alias, review_text
)
select id, user_id, experience_key, experience_title,
       '검증별칭', '검증 공개 후기'
  from public.experience_records
 where experience_key = '__week1_rls_test__'
   and user_id = (select user_id from week1_test_users where label = 'owner');

insert into week1_test_results (check_no, check_name, expected, actual, passed)
select 1, '본인 기록 조회', '1건', count(*)::text || '건', count(*) = 1
  from public.experience_records
 where experience_key = '__week1_rls_test__';

-- 관리자는 다른 사용자의 응답 원문과 공개 후기를 모두 조회할 수 있습니다.
select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from week1_test_users where label = 'admin'),
  true
);

insert into week1_test_results (check_no, check_name, expected, actual, passed)
select 2, '관리자 타인 응답·피드백 조회',
       '1건과 원문 표시',
       count(*)::text || '건 / ' ||
       coalesce(max(response_data ->> 'answer'), '응답 없음') || ' / ' ||
       coalesce(max(feedback_text), '피드백 없음'),
       count(*) = 1
       and max(response_data ->> 'answer') = '검증 응답'
       and max(feedback_text) = '검증 피드백'
  from public.experience_records
 where experience_key = '__week1_rls_test__';

update public.experience_reviews
   set is_hidden = true,
       hidden_at = now()
 where experience_key = '__week1_rls_test__';

insert into week1_test_results (check_no, check_name, expected, actual, passed)
select 3, '관리자 공개 후기 숨김', '1건',
       count(*) filter (where is_hidden = true)::text || '건',
       count(*) filter (where is_hidden = true) = 1
  from public.experience_reviews
 where experience_key = '__week1_rls_test__';

-- 익명 방문자는 관리자가 숨긴 후기를 볼 수 없어야 합니다.
reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

insert into week1_test_results (check_no, check_name, expected, actual, passed)
select 4, '익명 숨김 후기 차단', '0건', count(*)::text || '건', count(*) = 0
  from public.experience_reviews
 where experience_key = '__week1_rls_test__';

select check_no, check_name, expected, actual, passed
  from week1_test_results
 order by check_no;

reset role;
rollback;

-- 기대 결과.
-- 네 줄 모두 passed = true
-- 마지막 ROLLBACK으로 검증용 기록과 후기는 남지 않습니다.
