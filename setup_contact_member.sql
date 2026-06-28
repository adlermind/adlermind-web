-- contact_messages 조합원 공간 조회·삭제 권한 추가
-- Supabase 대시보드 > SQL Editor > New query 에서 실행

-- 기존 select 차단 정책 제거
DROP POLICY IF EXISTS "contact_select" ON public.contact_messages;
DROP POLICY IF EXISTS "contact_delete" ON public.contact_messages;

-- 조회·삭제 허용
CREATE POLICY "contact_select" ON public.contact_messages
  FOR SELECT USING (true);

CREATE POLICY "contact_delete" ON public.contact_messages
  FOR DELETE USING (true);

GRANT SELECT, DELETE ON public.contact_messages TO anon;
