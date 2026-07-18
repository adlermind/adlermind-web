-- 체험계정 저장 실패 원인을 변경 없이 조회하는 진단 SQL입니다.

select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'site_users'
order by ordinal_position;

select
  constraint_name,
  constraint_type,
  pg_get_constraintdef(pg_constraint.oid) as definition
from information_schema.table_constraints
join pg_constraint
  on pg_constraint.conname = information_schema.table_constraints.constraint_name
where table_schema = 'public'
  and table_name = 'site_users'
order by constraint_name;

select
  has_schema_privilege('service_role', 'public', 'USAGE') as service_role_schema_usage,
  has_table_privilege('service_role', 'public.site_users', 'INSERT') as service_role_insert,
  has_table_privilege('service_role', 'public.site_users', 'SELECT') as service_role_select;
