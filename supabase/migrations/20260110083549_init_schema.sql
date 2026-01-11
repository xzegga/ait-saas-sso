-- 1. EXTENSIONS
create extension if not exists "moddatetime";

-- 2. ENUMS & UTILS
-- (Add types here if needed in future)

-- ==============================================================================
-- 3. GLOBAL USER PROFILES & ADMINS
-- ==============================================================================

-- Super Admins Whitelist (Controlled manually)
create table public.super_admins (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  description text,
  created_at timestamptz default now()
);

-- Profiles: 1:1 with auth.users. 
-- ON DELETE CASCADE: If user is deleted in Auth, profile is wiped.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  role text default 'user', -- Global system role (user vs super_admin)
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null -- Soft Delete support
);

-- ==============================================================================
-- 4. PRODUCT CATALOG (Provider Side)
-- ==============================================================================

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  client_id text unique, -- e.g. 'prod_core_system'
  client_secret text,
  redirect_urls text[],
  created_at timestamptz default now(),
  deleted_at timestamptz default null -- Soft Delete support
);

create table public.product_role_definitions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade,
  role_name text not null,
  is_default boolean default false,
  unique(product_id, role_name)
);

create table public.product_features (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade,
  key text not null,
  description text,
  data_type text,
  unique(product_id, key)
);

create table public.product_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade,
  name text not null, -- e.g. "Free Tier"
  is_public boolean default true,
  created_at timestamptz default now(),
  deleted_at timestamptz default null -- Soft Delete support
);

create table public.plan_entitlements (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.product_plans(id) on delete cascade,
  feature_key text not null,
  value_text text,
  unique(plan_id, feature_key)
);

-- ==============================================================================
-- 5. ORGANIZATIONS (Consumer Side)
-- ==============================================================================

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  billing_email text,
  mfa_policy text default 'optional',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null -- Soft Delete support
);

create table public.org_product_subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  plan_id uuid references public.product_plans(id),
  status text check (status in ('active', 'trial', 'past_due', 'canceled')),
  quantity integer default 1,
  custom_entitlements jsonb default null,
  unique(org_id, product_id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Members: Links User <-> Org
-- ON DELETE CASCADE: If user is deleted, remove membership.
create table public.org_members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade, 
  status text default 'active',
  unique(org_id, user_id),
  created_at timestamptz default now()
);

-- Member Roles: Granular permissions per product within an Org
create table public.member_product_roles (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references public.org_members(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  role_definition_id uuid references public.product_role_definitions(id),
  unique(member_id, product_id)
);

-- ==============================================================================
-- 6. INVITATIONS SYSTEM
-- ==============================================================================

create table public.org_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade not null,
  email text not null,
  role text not null default 'Member', 
  -- ON DELETE CASCADE: If inviter is deleted, delete the invitation (prevent orphans)
  invited_by uuid references auth.users(id) on delete cascade, 
  token uuid default gen_random_uuid() unique not null,
  status text check (status in ('pending', 'accepted', 'expired')) default 'pending',
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '7 days'),
  unique(org_id, email)
);

create index idx_invitations_token on public.org_invitations(token);

-- ==============================================================================
-- 7. HELPER VIEWS & TRIGGERS
-- ==============================================================================

-- Automatic timestamp updates
create trigger handle_updated_at before update on public.organizations
  for each row execute procedure moddatetime (updated_at);
create trigger handle_updated_at before update on public.profiles
  for each row execute procedure moddatetime (updated_at);

-- View for debugging User Roles
create or replace view public.v_user_org_roles as
select 
  u.email,
  om.user_id,
  o.name as org_name,
  om.org_id,
  om.status as member_status,
  prd.role_name,
  p.name as product_name
from public.org_members om
join public.organizations o on om.org_id = o.id
join auth.users u on om.user_id = u.id
left join public.member_product_roles mpr on om.id = mpr.member_id
left join public.product_role_definitions prd on mpr.role_definition_id = prd.id
left join public.products p on prd.product_id = p.id;