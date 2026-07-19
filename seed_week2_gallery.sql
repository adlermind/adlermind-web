-- [2-2] 지금 gallery.html 에 코드로 박혀 있는 창립총회 축하영상을 데이터로 옮깁니다.
-- setup_week2_gallery.sql 을 먼저 실행한 뒤에 실행하세요.
-- 여러 번 실행해도 같은 항목이 두 개 생기지 않습니다.

begin;

insert into public.site_gallery_sections (title, sort_order)
select '창립총회', 0
 where not exists (
   select 1 from public.site_gallery_sections where title = '창립총회'
 );

insert into public.site_gallery
  (section_id, media_type, title, meta_text, youtube_id, visibility, sort_order)
select
  section.id,
  'video',
  '아들러협동조합 창립총회 축하영상',
  '2026. 07. 13 · 2 MIN 14 SEC',
  's9_0Zgx4tT0',
  'public',
  0
  from public.site_gallery_sections as section
 where section.title = '창립총회'
   and not exists (
     select 1 from public.site_gallery where youtube_id = 's9_0Zgx4tT0'
   );

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────────────
select section.title as 섹션, gallery.title as 제목, gallery.media_type,
       gallery.youtube_id, gallery.visibility, gallery.sort_order
  from public.site_gallery as gallery
  join public.site_gallery_sections as section on section.id = gallery.section_id
 order by section.sort_order, gallery.sort_order;
