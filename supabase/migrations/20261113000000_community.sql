-- Community: workout posts visible to every signed-in user, and likes.
--
-- posts       one shared workout: a copy of its stats, an optional caption
--             and the share-card image the author picked
-- post_likes  one row per (post, user)
-- storage     bucket community-posts, files under <user id>/<post id>.png
--
-- The author's display name is copied onto the post (author_name) so readers
-- never need access to other users' profiles rows, which stay private.
-- Additive only.

create table if not exists public.posts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid()
                       references auth.users (id) on delete cascade,
  author_name        text not null
                       check (char_length(btrim(author_name)) between 1 and 40),
  workout_session_id uuid references public.workout_sessions (id) on delete set null,
  exercise_name      text not null,
  stats              jsonb not null default '{}',  -- {"reps","avgFormPct","durationMs","kcal","sets"}
  caption            text check (caption is null or char_length(caption) <= 280),
  image_url          text,
  created_at         timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts (created_at desc);

create table if not exists public.post_likes (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists post_likes_user_idx on public.post_likes (user_id);

alter table public.posts      enable row level security;
alter table public.post_likes enable row level security;

do $$
begin
  -- Posts: everyone signed in reads; only the author writes.
  if not exists (select 1 from pg_policies where tablename = 'posts' and policyname = 'Signed-in users read posts') then
    create policy "Signed-in users read posts" on public.posts
      for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'posts' and policyname = 'Users create own posts') then
    create policy "Users create own posts" on public.posts
      for insert to authenticated with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'posts' and policyname = 'Users delete own posts') then
    create policy "Users delete own posts" on public.posts
      for delete to authenticated using (auth.uid() = user_id);
  end if;

  -- Likes: everyone signed in reads (counts); each user adds/removes own.
  if not exists (select 1 from pg_policies where tablename = 'post_likes' and policyname = 'Signed-in users read likes') then
    create policy "Signed-in users read likes" on public.post_likes
      for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'post_likes' and policyname = 'Users like as themselves') then
    create policy "Users like as themselves" on public.post_likes
      for insert to authenticated with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'post_likes' and policyname = 'Users remove own likes') then
    create policy "Users remove own likes" on public.post_likes
      for delete to authenticated using (auth.uid() = user_id);
  end if;
end $$;

-- Share-card images. Public bucket: files open by their URL; each user may
-- only upload into / delete from their own folder.
insert into storage.buckets (id, name, public)
values ('community-posts', 'community-posts', true)
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'Users upload own community images') then
    create policy "Users upload own community images" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'community-posts'
                  and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  -- Storage needs select as well as delete to remove a file.
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'Users read own community images') then
    create policy "Users read own community images" on storage.objects
      for select to authenticated
      using (bucket_id = 'community-posts'
             and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'Users delete own community images') then
    create policy "Users delete own community images" on storage.objects
      for delete to authenticated
      using (bucket_id = 'community-posts'
             and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
end $$;
