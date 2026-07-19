-- [2-3] 체험 콘텐츠 관리 — 표 하나와 접근 권한입니다.
-- 원칙: 콘텐츠를 코드가 아니라 데이터로. 관리자 페이지에서 등록하면 지정한 방과 대문에 바로 나타납니다.
-- 노출 위치와 공개 여부를 placement 한 칸으로 합쳤습니다. 고를 것이 하나라
-- "교육에 걸어놨는데 비공개였다" 같은 어긋남이 생기지 않습니다.
-- 기존 표(site_admins · member_accounts · experience_records · site_gallery)와 그 정책은 건드리지 않습니다.

begin;

create table if not exists public.experiences (
  id             uuid primary key default gen_random_uuid(),

  -- 두 홈페이지가 함께 쓰는 이름표입니다. 기관 이름을 넣지 않습니다.
  -- 심지에 이식해도 같은 체험은 같은 key 를 씁니다. 이름만 같을 뿐 응답 데이터는 섞이지 않습니다.
  -- experience_records.experience_key 와 이 값으로 이어집니다(외래키는 걸지 않습니다.
  -- 체험을 지워도 참여자의 기록은 남아야 하기 때문입니다).
  experience_key text not null unique
                 check (experience_key ~ '^[a-z0-9][a-z0-9-]*$'),

  title          text not null,
  summary        text,          -- 카드에 뜨는 한 줄 소개

  -- 어디에 내보낼지. hidden 은 보관 상태이며 관리자 화면에만 보입니다.
  placement      text not null default 'hidden'
                 check (placement in ('counseling', 'education', 'hidden')),

  -- html: 붙여넣은 단일 HTML 을 iframe 안에서 실행합니다.
  -- link: forest 설문처럼 다른 시스템에 있는 것. 카드를 누르면 그쪽으로 나갑니다.
  content_type   text not null default 'html'
                 check (content_type in ('html', 'link')),
  body_html      text,
  link_url       text,

  map_region     text,          -- 지도 구역. 9주차에 씁니다. 지금은 빈 칸으로 둡니다.
  sort_order     integer not null default 0,   -- 작은 숫자가 앞. 대문과 방이 같은 순서를 씁니다.
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint experiences_content_ref check (
    (content_type = 'html' and body_html is not null)
    or (content_type = 'link' and link_url is not null)
  )
);

create index if not exists experiences_placement_order_idx
  on public.experiences (placement, sort_order);

-- 수정한 시각을 자동으로 남깁니다.
create or replace function public.touch_experiences()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists experiences_touch on public.experiences;
create trigger experiences_touch
  before update on public.experiences
  for each row execute function public.touch_experiences();

-- ── GRANT (RLS 와는 별개의 층입니다. 둘 다 있어야 열립니다) ────
grant usage on schema public to anon, authenticated;
grant select on public.experiences to anon, authenticated;
grant insert, update, delete on public.experiences to authenticated;

-- ── RLS ────────────────────────────────────────────────────────
alter table public.experiences enable row level security;

drop policy if exists "체험 공개 조회" on public.experiences;
drop policy if exists "체험 회원 조회" on public.experiences;
drop policy if exists "체험 등록"     on public.experiences;
drop policy if exists "체험 수정"     on public.experiences;
drop policy if exists "체험 삭제"     on public.experiences;

-- 체험은 로그인 없이 누구나 해보는 것이 기획의 핵심(4-1)이라 조합원 공개 단계를 두지 않습니다.
create policy "체험 공개 조회" on public.experiences
  for select to anon using (placement <> 'hidden');

-- 로그인한 사람도 같은 것을 보되, 관리자는 보관 중인 것까지 봅니다.
create policy "체험 회원 조회" on public.experiences
  for select to authenticated using (
    placement <> 'hidden'
    or (select public.is_active_admin())
  );

create policy "체험 등록" on public.experiences
  for insert to authenticated with check ((select public.is_active_admin()));
create policy "체험 수정" on public.experiences
  for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));
create policy "체험 삭제" on public.experiences
  for delete to authenticated using ((select public.is_active_admin()));

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────────────
select c.relname as table_name, c.relrowsecurity as row_security
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname = 'experiences';

select tablename, policyname, roles, cmd
  from pg_policies
 where schemaname = 'public' and tablename = 'experiences'
 order by cmd, policyname;
