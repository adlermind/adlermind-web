-- 체험계정 Edge Function에 site_users 별칭 등록에 필요한 최소 권한만 부여합니다.

grant usage on schema public to service_role;
grant insert on public.site_users to service_role;

select
  has_schema_privilege('service_role', 'public', 'USAGE') as service_role_schema_usage,
  has_table_privilege('service_role', 'public.site_users', 'INSERT') as service_role_insert;
