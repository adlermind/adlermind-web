-- [2-2] 갤러리 사진 저장소 — 버킷 하나와 정책입니다.
-- setup_week2_gallery.sql 을 먼저 실행한 뒤에 실행하세요. (site_gallery 표를 되짚어 보기 때문입니다)
--
-- 왜 비공개 버킷인가:
--   조합원 공개 사진이 있으므로 PUBLIC 버킷은 쓸 수 없습니다. URL 을 아는 사람이 다 보게 됩니다.
--   버킷을 공개용·조합원용 둘로 나누면 공개 범위를 바꿀 때마다 파일을 옮겨야 해서 실수가 납니다.
--   그래서 버킷은 하나로 두고, 정책이 site_gallery 행의 visibility 를 직접 보게 했습니다.
--   공개 범위가 표의 한 곳에만 있고, 관리자 화면에서 선택만 바꾸면 사진 접근 권한이 따라옵니다.
--
-- 기존 board-files · receipts 버킷과 그 정책은 건드리지 않습니다.

begin;

-- 버킷 생성. public = false 이므로 서명 URL 로만 열립니다.
insert into storage.buckets (id, name, public)
values ('gallery-images', 'gallery-images', false)
on conflict (id) do update set public = false;

-- 이 버킷에 걸려 있던 이전 정책이 있다면 먼저 걷어냅니다.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and (coalesce(qual, '') like '%gallery-images%'
         or coalesce(with_check, '') like '%gallery-images%')
  loop
    execute format('drop policy if exists %I on storage.objects', policy_record.policyname);
  end loop;
end
$$;

-- 로그인하지 않은 사람: 공개 항목에 붙은 사진만 열립니다.
create policy "갤러리 사진 공개 조회" on storage.objects
  for select to anon
  using (
    bucket_id = 'gallery-images'
    and exists (
      select 1 from public.site_gallery as gallery
       where gallery.image_path = storage.objects.name
         and gallery.visibility = 'public'
    )
  );

-- 로그인한 사람: 공개 항목 + (활성 조합원이면 조합원 공개) + (관리자면 전부).
-- 관리자 조건을 따로 둔 이유는 사진을 올린 직후 아직 site_gallery 행이 없을 때도
-- 미리보기를 열어야 하기 때문입니다.
create policy "갤러리 사진 회원 조회" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'gallery-images'
    and (
      (select public.is_active_admin())
      or exists (
        select 1 from public.site_gallery as gallery
         where gallery.image_path = storage.objects.name
           and (
             gallery.visibility = 'public'
             or (gallery.visibility = 'members' and (select public.is_active_member()))
           )
      )
    )
  );

create policy "갤러리 사진 등록" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'gallery-images' and (select public.is_active_admin()));

create policy "갤러리 사진 수정" on storage.objects
  for update to authenticated
  using (bucket_id = 'gallery-images' and (select public.is_active_admin()))
  with check (bucket_id = 'gallery-images' and (select public.is_active_admin()));

create policy "갤러리 사진 삭제" on storage.objects
  for delete to authenticated
  using (bucket_id = 'gallery-images' and (select public.is_active_admin()));

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────────────
select id, name, public from storage.buckets where id = 'gallery-images';

select policyname, roles, cmd
  from pg_policies
 where schemaname = 'storage'
   and tablename = 'objects'
   and (coalesce(qual, '') like '%gallery-images%'
     or coalesce(with_check, '') like '%gallery-images%')
 order by cmd, policyname;
