-- 체험후기 테이블 및 RLS 설정
-- 2-5주차: 관리자가 골라 등록한 체험후기를 첫화면에 표시

CREATE TABLE IF NOT EXISTS public.experience_testimonials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alias text NOT NULL,              -- 별칭 (예: "김O")
  program_label text NOT NULL,      -- 활용 프로그램 (자유입력, 예: "상담")
  body text NOT NULL,               -- 후기 전체 내용
  photo_path text,                  -- experience-thumbs/testimonials/ 경로 (선택)
  sort_order integer NOT NULL DEFAULT 0,
  is_visible boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_experience_testimonials_is_visible
  ON public.experience_testimonials(is_visible);
CREATE INDEX IF NOT EXISTS idx_experience_testimonials_sort_order
  ON public.experience_testimonials(sort_order);

-- RLS 활성화
ALTER TABLE public.experience_testimonials ENABLE ROW LEVEL SECURITY;

-- 정책 1: anon은 공개된 후기만 조회
CREATE POLICY "select_public_testimonials_for_anon"
  ON public.experience_testimonials
  FOR SELECT
  TO anon
  USING (is_visible = true);

-- 정책 2: authenticated는 공개된 후기만 조회
CREATE POLICY "select_public_testimonials_for_auth"
  ON public.experience_testimonials
  FOR SELECT
  TO authenticated
  USING (is_visible = true);

-- 정책 3: 관리자만 insert/update/delete 가능
CREATE POLICY "admin_full_access_testimonials"
  ON public.experience_testimonials
  FOR ALL
  TO authenticated
  USING (public.is_active_admin())
  WITH CHECK (public.is_active_admin());

-- 권한 부여
GRANT SELECT ON public.experience_testimonials TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.experience_testimonials TO authenticated;
