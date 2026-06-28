-- ADLER MIND board_posts 401 Unauthorized fix.
-- Run in Supabase Dashboard > SQL Editor for project jboceiacgczkqkhqcmqu.

grant usage on schema public to anon;

grant select, insert, update, delete on public.board_posts to anon;
grant select, insert, update, delete on public.am_meetings to anon;
grant select, insert, update, delete on public.am_votes to anon;
grant select, insert, update, delete on public.am_availability to anon;

select
  has_table_privilege('anon', 'public.board_posts', 'SELECT') as board_posts_anon_select,
  has_table_privilege('anon', 'public.board_posts', 'INSERT') as board_posts_anon_insert,
  has_table_privilege('anon', 'public.board_posts', 'UPDATE') as board_posts_anon_update,
  has_table_privilege('anon', 'public.board_posts', 'DELETE') as board_posts_anon_delete;
