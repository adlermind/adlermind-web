-- [2-3] 체험 섬네일 — 칸 하나와 저장소 버킷입니다.
-- setup_week2_experiences.sql 을 먼저 실행한 뒤에 실행하세요.
--
-- 왜 공개 버킷인가:
--   갤러리와 다릅니다. 갤러리에는 조합원 공개 사진이 있어 비공개 버킷과 서명 URL 이 필요했지만,
--   체험은 로그인 없이 누구나 해보는 것이 기획의 핵심(4-1)이라 조합원 공개 단계가 없습니다.
--   섬네일이 뜨는 자리가 대문 첫 화면이므로, 서명 URL 로 매번 발급받으면 이미지마다 요청이 붙고
--   브라우저 캐시가 듣지 않아 첫 화면이 느려집니다. 감출 것이 없으니 공개 버킷으로 둡니다.
--
-- 기존 gallery-images · board-files · receipts 버킷과 그 정책은 건드리지 않습니다.

begin;

alter table public.experiences
  add column if not exists thumb_path text;   -- experience-thumbs 버킷 안의 경로

-- 버킷 생성. public = true 이므로 주소로 바로 열립니다.
insert into storage.buckets (id, name, public)
values ('experience-thumbs', 'experience-thumbs', true)
on conflict (id) do update set public = true;

-- 이 버킷에 걸려 있던 이전 정책이 있다면 먼저 걷어냅니다.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and (coalesce(qual, '') like '%experience-thumbs%'
         or coalesce(with_check, '') like '%experience-thumbs%')
  loop
    execute format('drop policy if exists %I on storage.objects', policy_record.policyname);
  end loop;
end
$$;

-- 읽기는 공개 버킷이라 정책 없이 열립니다. 올리고 고치고 지우는 것은 관리자만 합니다.
create policy "체험 섬네일 등록" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'experience-thumbs' and (select public.is_active_admin()));

create policy "체험 섬네일 수정" on storage.objects
  for update to authenticated
  using (bucket_id = 'experience-thumbs' and (select public.is_active_admin()))
  with check (bucket_id = 'experience-thumbs' and (select public.is_active_admin()));

create policy "체험 섬네일 삭제" on storage.objects
  for delete to authenticated
  using (bucket_id = 'experience-thumbs' and (select public.is_active_admin()));

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────────────
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'experiences' and column_name = 'thumb_path';

select id, name, public from storage.buckets where id = 'experience-thumbs';

select policyname, roles, cmd
  from pg_policies
 where schemaname = 'storage'
   and tablename = 'objects'
   and (coalesce(qual, '') like '%experience-thumbs%'
     or coalesce(with_check, '') like '%experience-thumbs%')
 order by cmd, policyname;
