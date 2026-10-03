begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 80),
  phone text not null default '',
  home_state text not null default '',
  driver_type text not null default 'Company driver',
  preferred_language text not null default 'English',
  preferred_plan text not null default 'Standard Plus',
  local_notifications boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  service text not null check (service in ('Legal','Health','Financial','Benefits','General')),
  title text not null check (char_length(trim(title)) between 3 and 100),
  details text not null check (char_length(trim(details)) between 10 and 3000),
  location text not null default '',
  incident_date date not null,
  status text not null default 'draft' check (status = 'draft'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.request_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  storage_path text not null unique,
  original_name text not null check (char_length(original_name) between 1 and 255),
  mime_type text not null check (mime_type in (
    'application/pdf','image/png','image/jpeg','image/heic','image/heif','text/plain'
  )),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 26214400),
  created_at timestamptz not null default now(),
  check (position('/' in storage_path) > 1),
  constraint request_documents_owned_request_fk
    foreign key (request_id, user_id) references public.requests(id, user_id) on delete cascade
);

create table public.user_saves (
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('offer','article','listing')),
  item_id text not null check (char_length(item_id) between 1 and 120),
  created_at timestamptz not null default now(),
  primary key (user_id, kind, item_id)
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 100),
  body text not null check (char_length(trim(body)) between 10 and 3000),
  visibility text not null default 'private' check (visibility = 'private'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create table public.replies (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  constraint replies_owned_post_fk
    foreign key (post_id, user_id) references public.posts(id, user_id) on delete cascade
);

create table public.activity_notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  detail text not null check (char_length(detail) between 1 and 500),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index requests_user_updated_idx on public.requests(user_id, updated_at desc);
create index request_documents_request_idx on public.request_documents(request_id);
create index request_documents_user_idx on public.request_documents(user_id);
create index posts_user_updated_idx on public.posts(user_id, updated_at desc);
create index replies_post_created_idx on public.replies(post_id, created_at);
create index activity_notices_user_created_idx on public.activity_notices(user_id, created_at desc);

create function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger requests_set_updated_at
before update on public.requests
for each row execute function public.set_updated_at();

create trigger posts_set_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

revoke execute on function public.set_updated_at() from public, anon, authenticated;

alter table public.profiles enable row level security;
alter table public.requests enable row level security;
alter table public.request_documents enable row level security;
alter table public.user_saves enable row level security;
alter table public.posts enable row level security;
alter table public.replies enable row level security;
alter table public.activity_notices enable row level security;

revoke all on public.profiles, public.requests, public.request_documents,
  public.user_saves, public.posts, public.replies, public.activity_notices from anon;

grant select, insert, update, delete on public.profiles, public.requests,
  public.request_documents, public.user_saves, public.posts, public.replies,
  public.activity_notices to authenticated;
create policy profiles_select_own
on public.profiles for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy profiles_insert_own
on public.profiles for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy profiles_update_own
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy profiles_delete_own
on public.profiles for delete to authenticated
using ((select auth.uid()) = id);

create policy requests_select_own
on public.requests for select to authenticated
using ((select auth.uid()) = user_id);

create policy requests_insert_own
on public.requests for insert to authenticated
with check ((select auth.uid()) = user_id and status = 'draft');

create policy requests_update_own
on public.requests for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id and status = 'draft');

create policy requests_delete_own
on public.requests for delete to authenticated
using ((select auth.uid()) = user_id);
create policy request_documents_select_own
on public.request_documents for select to authenticated
using ((select auth.uid()) = user_id);

create policy request_documents_insert_own
on public.request_documents for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and split_part(storage_path, '/', 1) = (select auth.uid())::text
  and exists (
    select 1 from public.requests r
    where r.id = request_id and r.user_id = (select auth.uid())
  )
);

create policy request_documents_update_own
on public.request_documents for update to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and split_part(storage_path, '/', 1) = (select auth.uid())::text
  and exists (
    select 1 from public.requests r
    where r.id = request_id and r.user_id = (select auth.uid())
  )
);

create policy request_documents_delete_own
on public.request_documents for delete to authenticated
using ((select auth.uid()) = user_id);

create policy user_saves_select_own
on public.user_saves for select to authenticated
using ((select auth.uid()) = user_id);
create policy user_saves_insert_own
on public.user_saves for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy user_saves_delete_own
on public.user_saves for delete to authenticated
using ((select auth.uid()) = user_id);

create policy posts_select_own
on public.posts for select to authenticated
using ((select auth.uid()) = user_id);

create policy posts_insert_own
on public.posts for insert to authenticated
with check ((select auth.uid()) = user_id and visibility = 'private');

create policy posts_update_own
on public.posts for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id and visibility = 'private');

create policy posts_delete_own
on public.posts for delete to authenticated
using ((select auth.uid()) = user_id);

create policy replies_select_own_post
on public.replies for select to authenticated
using (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.posts p
    where p.id = post_id and p.user_id = (select auth.uid())
  )
);
create policy replies_insert_own_post
on public.replies for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.posts p
    where p.id = post_id and p.user_id = (select auth.uid())
  )
);

create policy replies_delete_own
on public.replies for delete to authenticated
using ((select auth.uid()) = user_id);

create policy activity_notices_select_own
on public.activity_notices for select to authenticated
using ((select auth.uid()) = user_id);

create policy activity_notices_insert_own
on public.activity_notices for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy activity_notices_update_own
on public.activity_notices for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy activity_notices_delete_own
on public.activity_notices for delete to authenticated
using ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'request-documents',
  'request-documents',
  false,
  26214400,
  array['application/pdf','image/png','image/jpeg','image/heic','image/heif','text/plain']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
create policy request_documents_storage_select_own
on storage.objects for select to authenticated
using (
  bucket_id = 'request-documents'
  and owner_id = (select auth.uid())::text
);

create policy request_documents_storage_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'request-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy request_documents_storage_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'request-documents'
  and owner_id = (select auth.uid())::text
)
with check (
  bucket_id = 'request-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy request_documents_storage_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'request-documents'
  and owner_id = (select auth.uid())::text
);

commit;
