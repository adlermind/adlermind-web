-- ADLER MIND 협동조합 · 게시판에 「모두의 창업」 카테고리 더하기 (2026-10-27)
-- 프로젝트: jboceiacgczkqkhqcmqu (adlermindcoop 계정)
-- 실행 위치: Supabase 대시보드 > SQL Editor > New query 에 붙여넣고 실행
--
-- board_posts.category 는 '공지','회의록','서류' 셋만 받도록 check 제약이 걸려 있다.
-- 모두의 창업 서류를 한곳에 모으려고 '모두의 창업' 하나를 더한다.
-- 표·정책·기존 글은 건드리지 않는다. 다시 실행해도 같은 결과가 된다.

-- 1. category 에 걸린 check 제약을 이름과 상관없이 찾아 지운다
do $$
declare r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'board_posts'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%category%'
  loop
    execute format('alter table public.board_posts drop constraint %I', r.conname);
  end loop;
end $$;

-- 2. 네 가지를 받는 제약으로 다시 건다
alter table public.board_posts
  add constraint board_posts_category_check
  check (category in ('공지','회의록','서류','모두의 창업'));

-- 3. 진단 · 한 표로 본다. 두 줄 모두 passed = true 이면 된다
select '제약에 모두의 창업이 들어 있다' as check_name,
       exists (
         select 1 from pg_constraint
         where conname = 'board_posts_category_check'
           and pg_get_constraintdef(oid) like '%모두의 창업%'
       ) as passed
union all
select 'category 제약이 하나뿐이다',
       (select count(*) from pg_constraint con
          join pg_class rel on rel.oid = con.conrelid
         where rel.relname = 'board_posts' and con.contype = 'c'
           and pg_get_constraintdef(con.oid) ilike '%category%') = 1;
