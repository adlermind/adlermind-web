-- 게시글 확인(서명 갈음) 기능 — 2026-09-05
-- 회의록·총회 의사록 글에서 지정된 조합원이 본인 계정으로 "확인합니다"를 눌러
-- 정관 제29조·제25조의 서면 서명을 갈음한다.

-- 1. 표
create table if not exists public.board_confirmations (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.board_posts(id) on delete cascade,
  confirmer_name text not null,
  role text,
  user_id uuid references auth.users(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(post_id, confirmer_name)
);

create index if not exists idx_board_confirmations_post on public.board_confirmations(post_id);

-- 2. GRANT — 조합원 마당 전용 표. anon 에게는 주지 않는다.
grant usage on schema public to authenticated;
grant select, insert, delete on public.board_confirmations to authenticated;
-- update 는 authenticated 에게 주지 않는다. confirm_board_post() 함수(security definer)만 값을 채운다.

-- 3. RLS
alter table public.board_confirmations enable row level security;

drop policy if exists "select_confirmations" on public.board_confirmations;
create policy "select_confirmations" on public.board_confirmations
  for select using (is_active_member() or is_active_admin());

drop policy if exists "insert_confirmations" on public.board_confirmations;
create policy "insert_confirmations" on public.board_confirmations
  for insert with check (is_active_member() or is_active_admin());

drop policy if exists "delete_confirmations" on public.board_confirmations;
create policy "delete_confirmations" on public.board_confirmations
  for delete using (is_active_member() or is_active_admin());

-- 4. 활성 조합원 이름 목록 — 글쓰기 화면의 "확인 필요 인원" 체크박스용
create or replace function public.list_active_members()
returns table(display_name text)
language sql stable security definer set search_path = ''
as $$
  select display_name from public.member_accounts
  where is_active = true
  order by display_name;
$$;

revoke all on function public.list_active_members() from public, anon;
grant execute on function public.list_active_members() to authenticated;

-- 5. 본인 확인 처리 — 로그인 계정의 실명과 명단의 이름이 같을 때만 그 행을 채운다.
--    남의 이름을 대신 확인할 수 없다. 이미 확인된 행은 다시 바뀌지 않는다.
create or replace function public.confirm_board_post(p_post_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_name text;
begin
  select display_name into v_name
  from public.member_accounts
  where user_id = auth.uid() and is_active = true
  limit 1;

  if v_name is null then
    raise exception 'not an active member';
  end if;

  update public.board_confirmations
  set user_id = auth.uid(), confirmed_at = now()
  where post_id = p_post_id
    and confirmer_name = v_name
    and user_id is null;
end;
$$;

revoke all on function public.confirm_board_post(uuid) from public, anon;
grant execute on function public.confirm_board_post(uuid) to authenticated;

-- 진단
select 'board_confirmations 표' as check_name,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='board_confirmations') as passed
union all
select 'list_active_members 함수', exists(select 1 from pg_proc where proname='list_active_members')
union all
select 'confirm_board_post 함수', exists(select 1 from pg_proc where proname='confirm_board_post');
