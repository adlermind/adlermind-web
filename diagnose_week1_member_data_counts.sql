-- 조합원 마당 데이터가 삭제되지 않았는지 테이블별 행 수만 확인합니다.

select 'board_posts' as table_name, count(*) as row_count from public.board_posts
union all select 'board_comments', count(*) from public.board_comments
union all select 'am_meetings', count(*) from public.am_meetings
union all select 'am_votes', count(*) from public.am_votes
union all select 'am_availability', count(*) from public.am_availability
union all select 'accounting_records', count(*) from public.accounting_records
union all select 'am_ideas', count(*) from public.am_ideas
union all select 'contact_messages', count(*) from public.contact_messages
order by table_name;

select
  count(*) filter (where is_active) as active_member_rows,
  count(*) filter (where is_active and user_id is not null) as linked_member_rows
from public.member_accounts;
