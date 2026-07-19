-- [2-2] 갤러리 관리 — 표 2개와 접근 권한입니다.
-- 원칙: 콘텐츠를 코드가 아니라 데이터로. 관리자 페이지에서 등록하면 gallery.html 에 바로 나타납니다.
-- 공개 범위는 site_gallery.visibility 한 곳에만 둡니다. 사진 파일 접근 권한도 이 값을 따라갑니다.
-- 기존 테이블(site_admins · member_accounts · board-files 버킷)과 그 정책은 건드리지 않습니다.

begin;

-- ── 표 1. 갤러리 섹션 ──────────────────────────────────────────
-- 섹션 이름을 한 곳에서 고치고 순서를 바꾸기 위해 따로 둡니다.
create table if not exists public.site_gallery_sections (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- ── 표 2. 갤러리 항목 ──────────────────────────────────────────
create table if not exists public.site_gallery (
  id          uuid primary key default gen_random_uuid(),
  section_id  uuid not null references public.site_gallery_sections(id) on delete cascade,
  media_type  text not null default 'photo' check (media_type in ('photo', 'video')),
  title       text not null,
  description text,
  image_path  text,          -- gallery-images 버킷 안의 경로. storage.objects.name 과 정확히 같아야 합니다.
  youtube_id  text,          -- 영상은 파일 업로드가 아니라 YouTube ID 로 답니다.
  meta_text   text,          -- 카드 아래 한 줄. 예: 2026. 07. 13 · 2 MIN 14 SEC
  visibility  text not null default 'public'
              check (visibility in ('public', 'members', 'private')),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- 영상은 youtube_id 가, 사진은 image_path 가 반드시 있어야 합니다.
  constraint site_gallery_media_ref check (
    (media_type = 'video' and youtube_id is not null)
    or (media_type = 'photo' and image_path is not null)
  )
);

create index if not exists site_gallery_section_idx
  on public.site_gallery (section_id, sort_order);

-- image_path 로 storage 정책이 되짚어 오므로 찾기 빠르게 해 둡니다.
create index if not exists site_gallery_image_path_idx
  on public.site_gallery (image_path);

-- 수정한 시각을 자동으로 남깁니다.
create or replace function public.touch_site_gallery()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists site_gallery_touch on public.site_gallery;
create trigger site_gallery_touch
  before update on public.site_gallery
  for each row execute function public.touch_site_gallery();

-- ── GRANT (RLS 와는 별개의 층입니다. 둘 다 있어야 열립니다) ────
grant usage on schema public to anon, authenticated;
grant select on public.site_gallery_sections to anon, authenticated;
grant select on public.site_gallery          to anon, authenticated;
grant insert, update, delete on public.site_gallery_sections to authenticated;
grant insert, update, delete on public.site_gallery          to authenticated;

-- ── RLS ────────────────────────────────────────────────────────
alter table public.site_gallery_sections enable row level security;
alter table public.site_gallery          enable row level security;

drop policy if exists "갤러리 섹션 조회"   on public.site_gallery_sections;
drop policy if exists "갤러리 섹션 등록"   on public.site_gallery_sections;
drop policy if exists "갤러리 섹션 수정"   on public.site_gallery_sections;
drop policy if exists "갤러리 섹션 삭제"   on public.site_gallery_sections;
drop policy if exists "갤러리 항목 공개 조회" on public.site_gallery;
drop policy if exists "갤러리 항목 회원 조회" on public.site_gallery;
drop policy if exists "갤러리 항목 등록"   on public.site_gallery;
drop policy if exists "갤러리 항목 수정"   on public.site_gallery;
drop policy if exists "갤러리 항목 삭제"   on public.site_gallery;

-- 섹션 이름 자체는 감출 것이 없습니다. 보여줄 항목이 없는 섹션은 화면에 그리지 않습니다.
create policy "갤러리 섹션 조회" on public.site_gallery_sections
  for select to anon, authenticated using (true);
create policy "갤러리 섹션 등록" on public.site_gallery_sections
  for insert to authenticated with check ((select public.is_active_admin()));
create policy "갤러리 섹션 수정" on public.site_gallery_sections
  for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));
create policy "갤러리 섹션 삭제" on public.site_gallery_sections
  for delete to authenticated using ((select public.is_active_admin()));

-- 로그인하지 않은 사람은 공개 항목만 봅니다.
create policy "갤러리 항목 공개 조회" on public.site_gallery
  for select to anon using (visibility = 'public');

-- 로그인한 사람은 공개 항목 + (활성 조합원이면 조합원 공개) + (관리자면 전부) 를 봅니다.
create policy "갤러리 항목 회원 조회" on public.site_gallery
  for select to authenticated using (
    visibility = 'public'
    or (visibility = 'members' and (select public.is_active_member()))
    or (select public.is_active_admin())
  );

create policy "갤러리 항목 등록" on public.site_gallery
  for insert to authenticated with check ((select public.is_active_admin()));
create policy "갤러리 항목 수정" on public.site_gallery
  for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));
create policy "갤러리 항목 삭제" on public.site_gallery
  for delete to authenticated using ((select public.is_active_admin()));

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────────────
select tablename, policyname, roles, cmd
  from pg_policies
 where schemaname = 'public'
   and tablename in ('site_gallery', 'site_gallery_sections')
 order by tablename, cmd, policyname;
