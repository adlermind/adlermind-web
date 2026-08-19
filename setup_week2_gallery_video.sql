-- [갤러리] 영상 파일 직접 올리기 — 2026-08-20
-- 왜: 1분 안 되는 짧은 행사 영상을 YouTube 에 올렸다 내렸다 하는 것이 번거롭습니다.
--     YouTube 방식은 그대로 두고, 파일을 직접 올리는 길을 하나 더 냅니다.
--
-- setup_week2_gallery.sql 과 setup_week2_gallery_storage.sql 을 먼저 실행한 뒤에 실행하세요.
-- 기존 사진·YouTube 항목은 건드리지 않습니다. 열 하나가 늘고 정책 두 개가 바뀝니다.

begin;

-- ── 1. 영상 파일 경로를 담을 열 ────────────────────────────────
-- 사진의 image_path 와 같은 자리입니다. gallery-images 버킷 안의 경로를 담습니다.
alter table public.site_gallery
  add column if not exists video_path text;

-- ── 2. 제약 고치기 ─────────────────────────────────────────────
-- 지금까지 영상은 youtube_id 가 반드시 있어야 했습니다.
-- 이제 영상은 youtube_id 나 video_path 둘 중 하나만 있으면 됩니다.
alter table public.site_gallery
  drop constraint if exists site_gallery_media_ref;

alter table public.site_gallery
  add constraint site_gallery_media_ref check (
    (media_type = 'video' and (youtube_id is not null or video_path is not null))
    or (media_type = 'photo' and image_path is not null)
  );

-- video_path 로 storage 정책이 되짚어 오므로 찾기 빠르게 해 둡니다.
create index if not exists site_gallery_video_path_idx
  on public.site_gallery (video_path);

commit;

-- ── 3. 저장소 정책 ─────────────────────────────────────────────
-- 사진과 똑같은 방식입니다. site_gallery 행의 visibility 를 정책이 직접 봅니다.
-- 달라진 것은 image_path 뿐 아니라 video_path 도 함께 본다는 점입니다.
-- 조합원 공개로 두면 영상 파일도 조합원에게만 열립니다.

begin;

drop policy if exists "갤러리 사진 공개 조회" on storage.objects;
drop policy if exists "갤러리 사진 회원 조회" on storage.objects;

-- 로그인하지 않은 사람: 공개 항목에 붙은 사진·영상만 열립니다.
create policy "갤러리 사진 공개 조회" on storage.objects
  for select to anon
  using (
    bucket_id = 'gallery-images'
    and exists (
      select 1 from public.site_gallery as gallery
       where (gallery.image_path = storage.objects.name
           or gallery.video_path = storage.objects.name)
         and gallery.visibility = 'public'
    )
  );

-- 로그인한 사람: 공개 항목 + (활성 조합원이면 조합원 공개) + (관리자면 전부).
-- 관리자 조건을 따로 둔 이유는 파일을 올린 직후 아직 site_gallery 행이 없을 때도
-- 미리보기를 열어야 하기 때문입니다.
create policy "갤러리 사진 회원 조회" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'gallery-images'
    and (
      (select public.is_active_admin())
      or exists (
        select 1 from public.site_gallery as gallery
         where (gallery.image_path = storage.objects.name
             or gallery.video_path = storage.objects.name)
           and (
             gallery.visibility = 'public'
             or (gallery.visibility = 'members' and (select public.is_active_member()))
           )
      )
    )
  );

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────────────
-- video_path 열이 생겼는지 봅니다.
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'site_gallery'
   and column_name in ('image_path', 'youtube_id', 'video_path')
 order by column_name;

-- 정책 두 개가 video_path 를 보고 있는지 봅니다.
select policyname, roles, cmd
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and coalesce(qual, '') like '%video_path%'
 order by policyname;
