-- ==============================================================================
-- BASE TABLES - Core Schema
-- ==============================================================================
-- This migration creates all core database tables in their final structure
-- Order: Extensions -> Base Tables -> Indexes
-- ==============================================================================

-- 1. EXTENSIONS
create extension if not exists "moddatetime";

-- ==============================================================================
-- 2. GLOBAL USER PROFILES & ADMINS
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
-- 3. PRODUCT CATALOG (Provider Side)
-- ==============================================================================

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  client_id text unique, -- e.g. 'prod_core_system'
  client_secret text,
  redirect_urls text[],
  status boolean default true not null, -- active/inactive (independent from deleted_at)
  created_at timestamptz default now(),
  deleted_at timestamptz default null -- Soft Delete support
);

comment on column public.products.status is 'Indicates if the product is active (true) or inactive (false). This is independent from deleted_at which is used for soft delete.';

create table public.product_role_definitions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade,
  role_name text not null,
  is_default boolean default false,
  unique(product_id, role_name)
);

-- Global entitlements catalog (reusable across all plans)
create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  key text not null unique, -- e.g. "max_users", "can_export_pdf", "storage_limit_gb"
  description text,
  data_type text not null default 'text', -- 'text', 'number', 'boolean'
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.entitlements is 'Global entitlements catalog. Entitlements are reusable across all plans.';
comment on column public.entitlements.key is 'Unique key identifier (e.g. "max_users", "can_export_pdf")';
comment on column public.entitlements.data_type is 'Data type: text, number, or boolean';

-- Independent plans (not tied to a specific product)
create table public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null, -- e.g. "Startup Tier", "Enterprise"
  description text,
  is_public boolean default true,
  status boolean default true not null, -- active/inactive (independent from deleted_at)
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.plans is 'Independent plans that can be assigned to multiple products.';
comment on column public.plans.status is 'Indicates if the plan is active (true) or inactive (false). Independent from deleted_at.';

-- Links plans to entitlements with specific values
create table public.plan_entitlements (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.plans(id) on delete cascade not null,
  entitlement_id uuid references public.entitlements(id) on delete cascade not null,
  value_text text, -- Stores the value as text (can be parsed based on entitlement.data_type)
  created_at timestamptz default now(),
  unique(plan_id, entitlement_id)
);

comment on table public.plan_entitlements is 'Links plans to entitlements with specific values.';
comment on column public.plan_entitlements.value_text is 'The value for this entitlement in this plan (stored as text, parse based on entitlement.data_type)';

-- Many-to-many relationship between products and plans with pricing
create table public.product_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade not null,
  plan_id uuid references public.plans(id) on delete cascade not null,
  price decimal(10, 2), -- Price for this plan in this product (can be null for free plans)
  currency text default 'USD',
  is_public boolean default true, -- Can override plan.is_public
  status boolean default true not null, -- active/inactive for this product
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null,
  unique(product_id, plan_id)
);

comment on table public.product_plans is 'Many-to-many relationship between products and plans. Each relationship can have a different price.';
comment on column public.product_plans.price is 'Price for this plan in this product (null for free plans)';
comment on column public.product_plans.currency is 'Currency code (e.g. USD, EUR)';
comment on column public.product_plans.status is 'Active/inactive status for this product-plan relationship';

-- Role templates for reusing role definitions across products
create table public.role_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  roles jsonb not null default '[]'::jsonb, -- Array of { role_name: text, is_default: boolean }
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  created_by uuid references auth.users(id) on delete set null
);

-- ==============================================================================
-- 4. ORGANIZATIONS (Consumer Side)
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
  plan_id uuid references public.plans(id), -- References plans.id (not product_plans.id)
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
-- 5. INVITATIONS SYSTEM
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

-- ==============================================================================
-- 6. RECYCLE BIN
-- ==============================================================================

create table public.recycle_bin (
  id bigserial primary key,
  
  -- Entity information
  entity_type text not null check (length(entity_type) > 0 and length(entity_type) <= 50),
  entity_id text not null check (length(entity_id) > 0 and length(entity_id) <= 255),
  entity_display_name text not null check (length(entity_display_name) > 0 and length(entity_display_name) <= 255),
  
  -- Deletion audit
  deleted_by_id uuid not null references auth.users(id),
  deleted_by_name text not null check (length(deleted_by_name) > 0 and length(deleted_by_name) <= 255),
  deleted_at timestamptz not null default now(),
  reason text,
  
  -- Restoration information
  restored_at timestamptz,
  restored_by_id uuid references auth.users(id),
  restored_by_name text check (length(restored_by_name) <= 255),
  can_restore boolean not null default true,
  
  -- Timestamps
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  
  -- Constraint: cannot restore twice
  constraint check_restore check (
    (restored_at is null and restored_by_id is null) or 
    (restored_at is not null and restored_by_id is not null)
  )
);

comment on table public.recycle_bin is 'Recycle bin for soft-deleted entities. Allows restoration of deleted items.';
comment on column public.recycle_bin.entity_type is 'Type of deleted entity (e.g., products, plans, entitlements, product_plans, organizations, profiles, product_role_definitions)';
comment on column public.recycle_bin.entity_id is 'ID of the deleted record in its original table (UUID as text)';
comment on column public.recycle_bin.entity_display_name is 'Human-readable name of the record for UI display';
comment on column public.recycle_bin.deleted_by_id is 'UUID of the user who deleted the record';
comment on column public.recycle_bin.deleted_by_name is 'Name of the user who deleted (snapshot at deletion time)';
comment on column public.recycle_bin.deleted_at is 'Deletion date and time';
comment on column public.recycle_bin.reason is 'Optional reason for deletion';
comment on column public.recycle_bin.restored_at is 'Restoration date and time (if applicable)';
comment on column public.recycle_bin.restored_by_id is 'UUID of the user who restored the record';
comment on column public.recycle_bin.restored_by_name is 'Name of the user who restored (snapshot)';
comment on column public.recycle_bin.can_restore is 'Indicates if the record can be restored (integrity validation)';

-- ==============================================================================
-- 7. INDEXES
-- ==============================================================================

create index idx_invitations_token on public.org_invitations(token);
create index idx_role_templates_name on public.role_templates(name);
create index idx_entitlements_key on public.entitlements(key) where deleted_at is null;
create index idx_entitlements_deleted_at on public.entitlements(deleted_at);
create index idx_plans_deleted_at on public.plans(deleted_at);
create index idx_plans_status on public.plans(status) where deleted_at is null;
create index idx_plan_entitlements_plan_id on public.plan_entitlements(plan_id);
create index idx_plan_entitlements_entitlement_id on public.plan_entitlements(entitlement_id);
create index idx_product_plans_product_id on public.product_plans(product_id);
create index idx_product_plans_plan_id on public.product_plans(plan_id);
create index idx_product_plans_deleted_at on public.product_plans(deleted_at);
create index idx_recycle_bin_entity_type on public.recycle_bin(entity_type);
create index idx_recycle_bin_entity_id on public.recycle_bin(entity_id);
create index idx_recycle_bin_deleted_at on public.recycle_bin(deleted_at desc);
create index idx_recycle_bin_deleted_by_id on public.recycle_bin(deleted_by_id);
create index idx_recycle_bin_restored_at on public.recycle_bin(restored_at);
create index idx_recycle_bin_can_restore on public.recycle_bin(can_restore) where can_restore = true;
create index idx_recycle_bin_entity_type_id on public.recycle_bin(entity_type, entity_id) where restored_at is null;
