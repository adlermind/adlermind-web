-- ADLER MIND 협동조합 · membership_applications 조회 차단 (2026-09-02)
-- 실행 위치 · Supabase jboceiacgczkqkhqcmqu > SQL Editor
-- 실행 주체 · 트리님이 직접 실행합니다.
--
-- 왜 필요한가
--   지금 이 표는 누구나 조회할 수 있게 열려 있습니다.
--   주소만 알면 조합원 가입 신청자의 성명·생년월일·주소·전화번호·이메일을
--   그대로 읽을 수 있는 상태입니다.
--
-- 무엇을 바꾸는가
--   넣기(insert)는 그대로 두고, 읽기·고치기·지우기만 막습니다.
--   신청 폼은 계속 정상 작동합니다.
--
-- 신청 내용을 보시려면
--   Supabase 대시보드 > Table Editor 에서 보시면 됩니다.
--   대시보드는 anon 이 아니라 트리님 계정으로 접속하므로 이 차단과 무관합니다.

-- 1. anon 의 표 접근 권한을 넣기 하나로 좁힙니다.
revoke all on public.membership_applications from anon;
grant usage on schema public to anon;
grant insert on public.membership_applications to anon;

-- 2. RLS 를 켭니다. GRANT 와 RLS 는 서로 다른 두 층위라 둘 다 필요합니다.
alter table public.membership_applications enable row level security;

-- 3. 기존에 열려 있던 정책을 모두 걷어냅니다.
--    이름을 모르는 정책까지 지우기 위해 카탈로그를 훑습니다.
do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'membership_applications'
  loop
    execute format('drop policy if exists %I on public.membership_applications', p.policyname);
  end loop;
end $$;

-- 4. 넣기만 허용하는 정책 하나를 답니다.
create policy "누구나 가입신청을 넣습니다"
  on public.membership_applications for insert with check (true);

-- ── 확인 ────────────────────────────────────────────
-- 아래를 실행하면 정책이 insert 하나만 남아 있어야 합니다.
-- select policyname, cmd from pg_policies
--  where schemaname='public' and tablename='membership_applications';
