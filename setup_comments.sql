-- board_posts: visibility 컬럼 추가 (public | members)
alter table public.board_posts
  add column if not exists visibility text not null default 'members';

-- 기존 글 전부 조합원 전용으로 설정
update public.board_posts set visibility = 'members' where visibility is null or visibility = '';

-- board_comments 테이블
create table if not exists public.board_comments (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  post_id    uuid not null,
  parent_id  uuid,          -- NULL: 최상위 댓글 / uuid: 대댓글
  author     text not null,
  content    text not null
);

grant usage on schema public to anon;
grant select, insert, update, delete on public.board_comments to anon;

alter table public.board_comments enable row level security;

drop policy if exists "anon select board_comments"  on public.board_comments;
create policy "anon select board_comments"  on public.board_comments for select using (true);

drop policy if exists "anon insert board_comments"  on public.board_comments;
create policy "anon insert board_comments"  on public.board_comments for insert with check (true);

drop policy if exists "anon update board_comments"  on public.board_comments;
create policy "anon update board_comments"  on public.board_comments for update using (true);

drop policy if exists "anon delete board_comments"  on public.board_comments;
create policy "anon delete board_comments"  on public.board_comments for delete using (true);
