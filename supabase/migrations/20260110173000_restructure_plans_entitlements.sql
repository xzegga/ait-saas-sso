-- ==============================================================================
-- RESTRUCTURE PLANS & ENTITLEMENTS
-- ==============================================================================
-- This migration restructures the plans and entitlements system to support:
-- 1. Global entitlements (reusable across all plans)
-- 2. Independent plans (not tied to a specific product)
-- 3. Many-to-many relationship between products and plans with pricing
-- ==============================================================================

-- Step 1: Create entitlements table (global, reusable)
create table if not exists public.entitlements (
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

-- Step 2: Create plans table (independent, not tied to products)
create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null, -- e.g. "Startup Tier", "Enterprise"
  description text,
  is_public boolean default true,
  status boolean default true, -- active/inactive
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.plans is 'Independent plans that can be assigned to multiple products.';
comment on column public.plans.status is 'Indicates if the plan is active (true) or inactive (false). Independent from deleted_at.';

-- Step 3: Update plan_entitlements to use entitlements.id instead of feature_key
-- First, drop the old table if it exists and recreate it
drop table if exists public.plan_entitlements cascade;

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

-- Step 4: Prepare for product_plans restructure
-- First, drop the constraint on org_product_subscriptions BEFORE dropping product_plans
-- This is critical because org_product_subscriptions.plan_id references product_plans.id
alter table public.org_product_subscriptions
  drop constraint if exists org_product_subscriptions_plan_id_fkey;

-- Set plan_id to NULL for all existing records since we're changing the structure
-- These will need to be manually reassigned after creating new plans
update public.org_product_subscriptions
set plan_id = null
where plan_id is not null;

-- Now drop the old product_plans table
drop table if exists public.product_plans cascade;

create table public.product_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade not null,
  plan_id uuid references public.plans(id) on delete cascade not null,
  price decimal(10, 2), -- Price for this plan in this product (can be null for free plans)
  currency text default 'USD',
  is_public boolean default true, -- Can override plan.is_public
  status boolean default true, -- active/inactive for this product
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null,
  unique(product_id, plan_id)
);

comment on table public.product_plans is 'Many-to-many relationship between products and plans. Each relationship can have a different price.';
comment on column public.product_plans.price is 'Price for this plan in this product (null for free plans)';
comment on column public.product_plans.currency is 'Currency code (e.g. USD, EUR)';
comment on column public.product_plans.status is 'Active/inactive status for this product-plan relationship';

-- Step 5: Update org_product_subscriptions to reference plans.id instead of product_plans.id
-- The constraint was already dropped in Step 4, now add the new one pointing to plans.id
-- This will allow NULL values (plan_id column allows NULL)
alter table public.org_product_subscriptions
  add constraint org_product_subscriptions_plan_id_fkey
  foreign key (plan_id) references public.plans(id);

-- Step 6: Create indexes
create index idx_entitlements_key on public.entitlements(key) where deleted_at is null;
create index idx_entitlements_deleted_at on public.entitlements(deleted_at);
create index idx_plans_deleted_at on public.plans(deleted_at);
create index idx_plans_status on public.plans(status) where deleted_at is null;
create index idx_plan_entitlements_plan_id on public.plan_entitlements(plan_id);
create index idx_plan_entitlements_entitlement_id on public.plan_entitlements(entitlement_id);
create index idx_product_plans_product_id on public.product_plans(product_id);
create index idx_product_plans_plan_id on public.product_plans(plan_id);
create index idx_product_plans_deleted_at on public.product_plans(deleted_at);

-- Step 7: Create updated_at triggers
create trigger handle_entitlements_updated_at before update on public.entitlements
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_plans_updated_at before update on public.plans
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_product_plans_updated_at before update on public.product_plans
  for each row execute procedure public.moddatetime(updated_at);

-- Step 8: Enable RLS (policies will be added in next migration or here)
alter table public.entitlements enable row level security;
alter table public.plans enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.product_plans enable row level security;
