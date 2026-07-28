-- 기획마당에 조합원들이 올린 프로그램을 읽습니다.
-- 실행 위치: 아들러마인드 Supabase(jboceiacgczkqkhqcmqu) SQL Editor
-- 조회 전용입니다. 아무것도 바꾸지 않습니다.
--
-- 결과를 그대로 복사해 마루에게 주시면 검토합니다.

select
  life_task                     as "과제",
  life_stage                    as "대상",
  author                        as "담당자",
  program_title                 as "프로그램 제목",
  coalesce(sessions, '—')       as "회기",
  coalesce(wel_domain, '—')     as "5F-Wel",
  content                       as "프로그램 특징",
  case when source = 'admin' then '관리자 자료' else '조합원' end as "구분",
  coalesce(jsonb_array_length(resources), 0) as "자료수",
  to_char(created_at at time zone 'Asia/Seoul', 'MM-DD') as "올린날"
from public.am_ideas
order by
  case when source = 'admin' then 1 else 0 end,   -- 조합원 글을 먼저
  author,
  created_at;

-- 몇 건인지 한눈에
select count(*) filter (where source <> 'admin') as "조합원 글",
       count(*) filter (where source =  'admin') as "관리자 자료",
       count(*)                                  as "전체",
       count(distinct author)                    as "올린 사람 수"
  from public.am_ideas;
