-- [아들러 이야기] 공개 범위 — 글마다 '누구나'와 '회원방' 중에 고릅니다.
-- setup_stories.sql · setup_stories_series.sql 을 먼저 실행한 뒤에 실행하세요.
--
-- 왜 소식 게시판과 같은 이름(visibility)을 쓰는가:
--   board_posts 가 이미 'public' | 'members' 두 값을 씁니다. 같은 뜻에 다른 이름을 쓰면
--   나중에 두 게시판을 함께 다룰 때 어느 쪽 기준인지 매번 되짚어야 합니다.
--
-- 여기서 말하는 '회원'은 정식 이메일 회원(site_profiles 행이 있는 계정)입니다.
--   별칭 체험계정(site_users)은 회원방에 들어가지 않습니다. 이름만 있고 연락이 닿지 않는 계정이기 때문입니다.
--   조합원(member_accounts)과 관리자(site_admins)는 당연히 들어갑니다.

begin;

alter table public.am_stories
  add column if not exists visibility text not null default 'public';

do $blk$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'am_stories_visibility_check'
  ) then
    alter table public.am_stories
      add constraint am_stories_visibility_check
      check (visibility in ('public', 'members'));
  end if;
end
$blk$;

create index if not exists am_stories_visibility_idx
  on public.am_stories (visibility, is_published, published_at desc);

-- 정식 이메일 회원 판정. is_active_member() · is_active_admin() 와 같은 계층의 함수입니다.
create or replace function public.is_site_member()
returns boolean
language sql
stable
set search_path = ''
as $fn$
  select exists (
    select 1
      from public.site_profiles
     where user_id = (select auth.uid())
  );
$fn$;

revoke all on function public.is_site_member() from public, anon;
grant execute on function public.is_site_member() to authenticated;

-- ── 글 조회 정책 다시 걸기 ─────────────────────────────
-- 기존 "공개 이야기 조회" 는 공개 범위를 보지 않았으므로 바꿉니다.
drop policy if exists "공개 이야기 조회" on public.am_stories;
create policy "공개 이야기 조회" on public.am_stories
  for select to anon, authenticated
  using (is_published = true and visibility = 'public');

drop policy if exists "회원방 이야기 조회" on public.am_stories;
create policy "회원방 이야기 조회" on public.am_stories
  for select to authenticated
  using (
    is_published = true
    and visibility = 'members'
    and (
      (select public.is_site_member())
      or (select public.is_active_member())
      or (select public.is_active_admin())
    )
  );

-- 작성자·관리자 조회 정책("작성자 이야기 조회")은 그대로 둡니다. 초안까지 봐야 하기 때문입니다.

-- ── 댓글도 같은 기준을 따릅니다 ────────────────────────
-- 회원방 글의 댓글이 로그인하지 않은 사람에게 보이면 공개 범위가 새는 것입니다.
drop policy if exists "댓글 조회" on public.story_comments;
create policy "댓글 조회" on public.story_comments
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.am_stories as story
       where story.id = story_comments.story_id
         and story.is_published = true
         and (
           story.visibility = 'public'
           or (
             story.visibility = 'members'
             and (
               (select public.is_site_member())
               or (select public.is_active_member())
               or (select public.is_active_admin())
             )
           )
         )
    )
  );

-- 댓글 등록 함수도 회원방 글을 가려야 합니다.
-- 이 함수는 security definer 라 정책을 지나치므로 안에서 직접 확인합니다.
create or replace function public.add_story_comment(
  p_story_id  uuid,
  p_parent_id uuid,
  p_author    text,
  p_password  text,
  p_content   text
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_id         uuid;
  v_visibility text;
begin
  if length(btrim(coalesce(p_author, ''))) = 0 then
    raise exception '이름을 적어 주세요.';
  end if;
  if length(btrim(coalesce(p_content, ''))) = 0 then
    raise exception '댓글 내용을 적어 주세요.';
  end if;
  if length(coalesce(p_password, '')) < 4 then
    raise exception '비밀번호는 4자 이상으로 적어 주세요.';
  end if;
  if length(btrim(p_author)) > 20 or length(btrim(p_content)) > 1000 then
    raise exception '이름은 20자, 댓글은 1000자까지 적을 수 있습니다.';
  end if;

  select visibility into v_visibility
    from public.am_stories
   where id = p_story_id and is_published = true;

  if v_visibility is null then
    raise exception '글을 찾을 수 없습니다.';
  end if;

  -- 회원방 글에는 회원만 댓글을 답니다.
  if v_visibility = 'members'
     and not (
       public.is_site_member()
       or public.is_active_member()
       or public.is_active_admin()
     ) then
    raise exception '이 글은 회원방 글입니다. 로그인한 회원만 댓글을 남길 수 있습니다.';
  end if;

  if p_parent_id is not null and not exists (
    select 1 from public.story_comments
     where id = p_parent_id and story_id = p_story_id and parent_id is null
  ) then
    raise exception '답글을 달 댓글을 찾을 수 없습니다.';
  end if;

  insert into public.story_comments (story_id, parent_id, author_name, password_hash, content)
  values (
    p_story_id,
    p_parent_id,
    btrim(p_author),
    crypt(p_password, gen_salt('bf')),
    btrim(p_content)
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke all on function public.add_story_comment(uuid, uuid, text, text, text) from public;
grant execute on function public.add_story_comment(uuid, uuid, text, text, text) to anon, authenticated;

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────
select column_name, column_default, is_nullable
  from information_schema.columns
 where table_schema = 'public' and table_name = 'am_stories' and column_name = 'visibility';

select tablename, policyname, roles, cmd
  from pg_policies
 where schemaname = 'public'
   and tablename in ('am_stories', 'story_comments')
   and cmd = 'SELECT'
 order by tablename, policyname;
