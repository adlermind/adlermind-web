-- [아들러 이야기] 조합원 글 게시판 — 표 3개 · 함수 3개 · 저장소 1개
-- 실행 위치: Supabase 대시보드 > SQL Editor (프로젝트 jboceiacgczkqkhqcmqu · adlermindcoop 계정)
-- 기존 board_posts · site_gallery · board-files · gallery-images 와 그 정책은 건드리지 않습니다.
--
-- 왜 소식 게시판(board_posts)에 얹지 않았는가:
--   소식은 공지·회의록·서류를 확인하러 오는 기록이고, 이야기는 읽으러 오는 글입니다.
--   글마다 대표 그림·요약문·글쓴이가 필요하고 링크로 퍼뜨릴 주소가 있어야 합니다.
--   한 표에 섞으면 회의록 글에도 빈 칸이 따라다니고 조합원 게시판 화면도 같이 복잡해집니다.

begin;

create extension if not exists pgcrypto;

-- ── 1. 작성자 명단 ────────────────────────────────────
-- 관리자가 여기에 넣은 계정만 이야기를 쓸 수 있습니다. site_admins 와 같은 모양입니다.
create table if not exists public.story_authors (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  is_active    boolean not null default true,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create or replace function public.is_story_author()
returns boolean
language sql
stable
set search_path = ''
as $fn$
  select exists (
    select 1
      from public.story_authors
     where user_id = (select auth.uid())
       and is_active = true
  );
$fn$;

revoke all on function public.is_story_author() from public, anon;
grant execute on function public.is_story_author() to authenticated;

-- ── 2. 이야기 글 ──────────────────────────────────────
-- author_name 은 화면에 보이는 이름입니다. 작성자 명단의 이름으로 기본을 채우되
-- 관리자가 글마다 따로 고칠 수 있습니다(대필·공동 집필 글 때문입니다).
create table if not exists public.am_stories (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  title          text not null,
  summary        text,
  content        text not null default '',
  cover_path     text,          -- 'stories/{글id}/파일명' · 없으면 글자 카드로 보입니다
  author_name    text not null,
  author_user_id uuid references auth.users(id) on delete set null,
  is_published   boolean not null default false,
  published_at   timestamptz
);

create index if not exists am_stories_public_idx
  on public.am_stories (is_published, published_at desc);

-- ── 3. 댓글 ───────────────────────────────────────────
-- 로그인하지 않은 사람도 이름과 비밀번호로 답니다. 비밀번호는 해시로만 남고
-- anon 에게는 password_hash 열 자체를 읽을 권한을 주지 않습니다(아래 열 단위 grant).
create table if not exists public.story_comments (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  story_id      uuid not null references public.am_stories(id) on delete cascade,
  parent_id     uuid references public.story_comments(id) on delete cascade,
  author_name   text not null,
  password_hash text not null,
  content       text not null
);

create index if not exists story_comments_story_idx
  on public.story_comments (story_id, created_at);

-- ── 4. 권한 ───────────────────────────────────────────
grant usage on schema public to anon, authenticated;

-- 글: 밖에서는 공개된 글만 읽습니다.
revoke all on public.am_stories from anon, authenticated;
grant select on public.am_stories to anon;
grant select, insert, update, delete on public.am_stories to authenticated;
alter table public.am_stories enable row level security;

drop policy if exists "공개 이야기 조회" on public.am_stories;
create policy "공개 이야기 조회" on public.am_stories
  for select to anon, authenticated using (is_published = true);

drop policy if exists "작성자 이야기 조회" on public.am_stories;
create policy "작성자 이야기 조회" on public.am_stories
  for select to authenticated
  using ((select public.is_story_author()) or (select public.is_active_admin()));

drop policy if exists "작성자 이야기 등록" on public.am_stories;
create policy "작성자 이야기 등록" on public.am_stories
  for insert to authenticated
  with check (
    (select public.is_active_admin())
    or ((select public.is_story_author()) and author_user_id = (select auth.uid()))
  );

drop policy if exists "작성자 이야기 수정" on public.am_stories;
create policy "작성자 이야기 수정" on public.am_stories
  for update to authenticated
  using (
    (select public.is_active_admin())
    or ((select public.is_story_author()) and author_user_id = (select auth.uid()))
  )
  with check (
    (select public.is_active_admin())
    or ((select public.is_story_author()) and author_user_id = (select auth.uid()))
  );

drop policy if exists "작성자 이야기 삭제" on public.am_stories;
create policy "작성자 이야기 삭제" on public.am_stories
  for delete to authenticated
  using (
    (select public.is_active_admin())
    or ((select public.is_story_author()) and author_user_id = (select auth.uid()))
  );

-- 작성자 명단: 로그인한 사람은 읽고, 관리자만 고칩니다.
revoke all on public.story_authors from anon, authenticated;
grant select, insert, update, delete on public.story_authors to authenticated;
alter table public.story_authors enable row level security;

drop policy if exists "작성자 명단 조회" on public.story_authors;
create policy "작성자 명단 조회" on public.story_authors
  for select to authenticated using (true);

drop policy if exists "작성자 명단 등록" on public.story_authors;
create policy "작성자 명단 등록" on public.story_authors
  for insert to authenticated with check ((select public.is_active_admin()));

drop policy if exists "작성자 명단 수정" on public.story_authors;
create policy "작성자 명단 수정" on public.story_authors
  for update to authenticated
  using ((select public.is_active_admin()))
  with check ((select public.is_active_admin()));

drop policy if exists "작성자 명단 삭제" on public.story_authors;
create policy "작성자 명단 삭제" on public.story_authors
  for delete to authenticated using ((select public.is_active_admin()));

-- 댓글: 읽기는 열 단위로 허용해 비밀번호 해시를 감춥니다.
-- 등록은 표를 직접 건드리지 않고 아래 함수로만 합니다.
revoke all on public.story_comments from anon, authenticated;
grant select (id, created_at, story_id, parent_id, author_name, content)
  on public.story_comments to anon, authenticated;
grant delete on public.story_comments to authenticated;
alter table public.story_comments enable row level security;

drop policy if exists "댓글 조회" on public.story_comments;
create policy "댓글 조회" on public.story_comments
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.am_stories as story
       where story.id = story_comments.story_id
         and story.is_published = true
    )
  );

-- 글쓴이와 관리자는 자기 글에 달린 댓글을 지울 수 있습니다(광고 댓글 정리용).
drop policy if exists "댓글 관리 삭제" on public.story_comments;
create policy "댓글 관리 삭제" on public.story_comments
  for delete to authenticated
  using (
    (select public.is_active_admin())
    or exists (
      select 1 from public.am_stories as story
       where story.id = story_comments.story_id
         and story.author_user_id = (select auth.uid())
    )
  );

-- ── 5. 댓글 등록·삭제 함수 ────────────────────────────
-- crypt · gen_salt 는 pgcrypto 함수입니다. 설치 스키마가 프로젝트마다 다를 수 있어
-- search_path 를 비우지 않고 public, extensions 를 함께 둡니다.
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
  v_id uuid;
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
  if not exists (
    select 1 from public.am_stories where id = p_story_id and is_published = true
  ) then
    raise exception '글을 찾을 수 없습니다.';
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

create or replace function public.delete_story_comment(
  p_id       uuid,
  p_password text
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_hash text;
begin
  select password_hash into v_hash from public.story_comments where id = p_id;
  if v_hash is null then
    return false;
  end if;
  if v_hash = crypt(coalesce(p_password, ''), v_hash) then
    delete from public.story_comments where id = p_id;
    return true;
  end if;
  return false;
end;
$fn$;

revoke all on function public.add_story_comment(uuid, uuid, text, text, text) from public;
revoke all on function public.delete_story_comment(uuid, text) from public;
grant execute on function public.add_story_comment(uuid, uuid, text, text, text) to anon, authenticated;
grant execute on function public.delete_story_comment(uuid, text) to anon, authenticated;

commit;

-- ── 실행 후 확인용 읽기 쿼리 ───────────────────────────
select table_name
  from information_schema.tables
 where table_schema = 'public'
   and table_name in ('story_authors', 'am_stories', 'story_comments')
 order by table_name;

select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public'
   and tablename in ('story_authors', 'am_stories', 'story_comments')
 order by tablename, cmd, policyname;
