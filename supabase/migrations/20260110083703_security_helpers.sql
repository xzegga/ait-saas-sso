-- 1. Check if Super Admin
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'system_role') = 'super_admin', false);
$$;

-- 2. Get current Org ID from Token
create or replace function public.get_my_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid;
$$;

-- 3. Get current Role from Token
create or replace function public.get_my_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select (auth.jwt() -> 'app_metadata' ->> 'role')::text;
$$;

-- Grants
grant execute on function public.is_super_admin to public;
grant execute on function public.get_my_org_id to public;
grant execute on function public.get_my_role to public;