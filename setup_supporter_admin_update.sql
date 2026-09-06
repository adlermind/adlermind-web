-- ADLER MIND 협동조합 · 관리자가 회원관리 화면에서 후원 상태를 바꾸도록 (2026-09-06)
-- 실행 위치 · Supabase jboceiacgczkqkhqcmqu > SQL Editor
-- 실행 주체 · 트리님이 직접 실행합니다.
--
-- 하는 일 · am_supporters 에 "활성 관리자면 UPDATE 허용" 정책 하나를 더합니다.
--   입금을 확인하면 status 를 pending → active(+ paid_at), 필요하면 active → withdrawn 으로 바꿉니다.
--   후원회원은 감액·뉴스레터뿐이라 조합원·관리자 권한과 달리 화면에서 바꿔도 위험이 작습니다.
--   그래도 판정은 is_active_admin() 로만 하고, 브라우저가 임의로 못 바꾸게 합니다.

begin;

grant update on public.am_supporters to authenticated;

drop policy if exists "관리자가 후원 상태를 바꾼다" on public.am_supporters;
create policy "관리자가 후원 상태를 바꾼다"
  on public.am_supporters for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));

commit;

-- 확인용 --------------------------------------------------------------------
select policyname, cmd, roles
  from pg_policies
 where schemaname = 'public' and tablename = 'am_supporters'
 order by policyname;
