-- [아들러 이야기] 그림 저장소 — 버킷 하나와 정책입니다.
-- setup_stories.sql 을 먼저 실행한 뒤에 실행하세요. (is_story_author() 함수를 씁니다)
--
-- 왜 공개 버킷인가:
--   갤러리와 달리 여기 올라가는 그림은 처음부터 바깥에 보이라고 넣는 것입니다.
--   카카오톡·카페에 글 링크를 붙였을 때 대표 그림이 보이려면(og:image) 공개 주소여야 합니다.
--   비공개 버킷의 서명 주소는 시간이 지나면 끊겨서 미리보기가 깨집니다.
--   대신 올리고 고치고 지우는 권한은 지정된 작성자와 관리자에게만 둡니다.
--
-- 기존 board-files · receipts · gallery-images 버킷과 그 정책은 건드리지 않습니다.

begin;

insert into storage.buckets (id, name, public)
values ('story-images', 'story-images', true)
on conflict (id) do update set public = true;

-- 이 버킷에 걸려 있던 이전 정책이 있다면 먼저 걷어냅니다.
do $blk$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and (coalesce(qual, '') like '%story-images%'
         or coalesce(with_check, '') like '%story-images%')
  loop
    execute format('drop policy if exists %I on storage.objects', policy_record.policyname);
  end loop;
end
$blk$;

create policy "이야기 그림 조회" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'story-images');

create policy "이야기 그림 등록" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'story-images'
    and ((select public.is_story_author()) or (select public.is_active_admin()))
  );

create policy "이야기 그림 수정" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'story-images'
    and ((select public.is_story_author()) or (select public.is_active_admin()))
  )
  with check (
    bucket_id = 'story-images'
    and ((select public.is_story_author()) or (select public.is_active_admin()))
  );

create policy "이야기 그림 삭제" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'story-images'
    and ((select public.is_story_author()) or (select public.is_active_admin()))
  );

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────
select id, name, public from storage.buckets where id = 'story-images';

select policyname, roles, cmd
  from pg_policies
 where schemaname = 'storage'
   and tablename = 'objects'
   and (coalesce(qual, '') like '%story-images%'
     or coalesce(with_check, '') like '%story-images%')
 order by cmd, policyname;
