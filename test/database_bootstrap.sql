-- LOCAL TEST DATABASE ONLY. Do not run in Supabase or production.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema storage;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$$;
create function storage.foldername(text) returns text[] language sql immutable as $$
  select string_to_array($1,'/')
$$;
create table storage.buckets(id text primary key,name text,public boolean);
create table storage.objects(id bigint generated always as identity, bucket_id text, name text);
alter table storage.objects enable row level security;
grant usage on schema public, auth, storage to anon, authenticated;
grant execute on function auth.jwt(), storage.foldername(text) to authenticated;
