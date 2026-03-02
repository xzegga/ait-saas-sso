-- ==============================================================================
-- 001 - EXTENSIONS & BASE TABLES (consolidated, final schema from start)
-- ==============================================================================
-- Extensions, core tables with all columns (no add/alter in later migrations).
-- Order: Extensions -> Tables (dependencies first) -> Indexes
-- ==============================================================================

-- 1. EXTENSIONS
create extension if not exists "moddatetime";

-- ==============================================================================
-- 2. GLOBAL USER PROFILES & ADMINS
-- ==============================================================================

create table public.super_admins (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  description text,
  created_at timestamptz default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  role text default 'user',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

-- ==============================================================================
-- 3. PRODUCT CATALOG (Provider Side)
-- ==============================================================================

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  client_id text unique,
  client_secret text,
  redirect_urls text[],
  origin_urls text[],
  status boolean default true not null,
  trial_days integer default null,
  created_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on column public.products.status is 'Indicates if the product is active (true) or inactive (false). Independent from deleted_at.';
comment on column public.products.redirect_urls is 'Allowed redirect URLs after login (one per environment, e.g. http://localhost:3000, https://app.example.com).';
comment on column public.products.origin_urls is 'Allowed origin URLs for this product (e.g. http://localhost:5174). Requests must come from one of these origins. NULL or empty means no origin validation.';
comment on column public.products.trial_days is 'Default number of trial days for subscriptions to this product. NULL means no trial period.';

create table public.product_role_definitions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade,
  role_name text not null,
  is_default boolean default false,
  unique(product_id, role_name)
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text,
  data_type text not null default 'text',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.entitlements is 'Global entitlements catalog.';
comment on column public.entitlements.key is 'Unique key identifier (e.g. "max_users", "can_export_pdf")';
comment on column public.entitlements.data_type is 'Data type: text, number, or boolean';

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  is_public boolean default true,
  status boolean default true not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.plans is 'Independent plans that can be assigned to multiple products.';
comment on column public.plans.status is 'Indicates if the plan is active (true) or inactive (false).';

create table public.plan_entitlements (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.plans(id) on delete cascade not null,
  entitlement_id uuid references public.entitlements(id) on delete cascade not null,
  value_text text,
  created_at timestamptz default now(),
  unique(plan_id, entitlement_id)
);

comment on table public.plan_entitlements is 'Links plans to entitlements with specific values.';

create table public.product_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade not null,
  plan_id uuid references public.plans(id) on delete cascade not null,
  price decimal(10, 2),
  currency text default 'USD',
  is_public boolean default true,
  status boolean default true not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null,
  unique(product_id, plan_id)
);

comment on table public.product_plans is 'Many-to-many relationship between products and plans. Each relationship can have a different price.';

create table public.role_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  roles jsonb not null default '[]'::jsonb,
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
  deleted_at timestamptz default null
);

create table public.org_product_subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  plan_id uuid references public.plans(id),
  status text check (status in ('active', 'trial', 'past_due', 'canceled')),
  quantity integer default 1,
  custom_entitlements jsonb default null,
  trial_starts_at timestamptz,
  trial_ends_at timestamptz,
  unique(org_id, product_id),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint org_product_subscriptions_product_plan_fk
    foreign key (product_id, plan_id) references public.product_plans(product_id, plan_id) on delete restrict
);

comment on column public.org_product_subscriptions.trial_starts_at is 'When the trial period started (null if not a trial)';
comment on column public.org_product_subscriptions.trial_ends_at is 'When the trial period expires (null if not a trial or no expiration).';

create table public.org_members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  status text default 'active',
  unique(org_id, user_id),
  created_at timestamptz default now(),
  constraint org_members_user_id_profiles_fk foreign key (user_id) references public.profiles(id) on delete cascade
);

comment on constraint org_members_user_id_profiles_fk on public.org_members is 'Foreign key to profiles.id to enable PostgREST automatic joins.';

create table public.member_product_roles (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references public.org_members(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  role_definition_id uuid references public.product_role_definitions(id),
  unique(member_id, product_id)
);

-- ==============================================================================
-- 5. INVITATIONS
-- ==============================================================================

create table public.org_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade not null,
  email text not null,
  role text not null default 'Member',
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
  entity_type text not null check (length(entity_type) > 0 and length(entity_type) <= 50),
  entity_id text not null check (length(entity_id) > 0 and length(entity_id) <= 255),
  entity_display_name text not null check (length(entity_display_name) > 0 and length(entity_display_name) <= 255),
  deleted_by_id uuid not null references auth.users(id),
  deleted_by_name text not null check (length(deleted_by_name) > 0 and length(deleted_by_name) <= 255),
  deleted_at timestamptz not null default now(),
  reason text,
  restored_at timestamptz,
  restored_by_id uuid references auth.users(id),
  restored_by_name text check (length(restored_by_name) <= 255),
  can_restore boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  constraint check_restore check (
    (restored_at is null and restored_by_id is null) or
    (restored_at is not null and restored_by_id is not null)
  )
);

comment on table public.recycle_bin is 'Recycle bin for soft-deleted entities. Allows restoration of deleted items.';

-- ==============================================================================
-- 7. INDEXES (base tables)
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
create index idx_subscriptions_trial_expires on public.org_product_subscriptions(trial_ends_at) where status = 'trial' and trial_ends_at is not null;
