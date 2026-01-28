-- ==============================================================================
-- PRODUCT PLAN PRICES: Support multiple prices per billing interval
-- ==============================================================================
-- This migration creates a table to store multiple prices per product_plan
-- based on billing intervals (month, year, day, week). This allows plans
-- to have different pricing tiers based on subscription duration.
-- ==============================================================================

create table public.product_plan_prices (
  id uuid primary key default gen_random_uuid(),
  product_plan_id uuid references public.product_plans(id) on delete cascade not null,
  billing_interval text not null check (billing_interval in ('month', 'year', 'day', 'week')),
  price decimal(10, 2) not null,
  currency text default 'USD' not null,
  is_default boolean default false, -- Default price to show if no interval is specified
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(product_plan_id, billing_interval)
);

comment on table public.product_plan_prices is 'Stores multiple prices per product_plan based on billing intervals (month, year, day, week)';
comment on column public.product_plan_prices.billing_interval is 'Billing interval: month, year, day, or week';
comment on column public.product_plan_prices.price is 'Price for this billing interval';
comment on column public.product_plan_prices.is_default is 'If true, this is the default price to show when no interval is specified';

-- Index for faster lookups
create index idx_product_plan_prices_product_plan_id on public.product_plan_prices(product_plan_id);
create index idx_product_plan_prices_billing_interval on public.product_plan_prices(billing_interval);

-- Enable RLS
alter table public.product_plan_prices enable row level security;

-- RLS Policies: Same as product_plans
create policy "Public Read Product Plan Prices" on public.product_plan_prices for select 
  to authenticated using (
    exists (
      select 1 from public.product_plans pp 
      where pp.id = product_plan_prices.product_plan_id 
      and pp.deleted_at is null
    )
  );

create policy "Insert Product Plan Prices" on public.product_plan_prices for insert 
  to authenticated with check (public.is_super_admin());

create policy "Update Product Plan Prices" on public.product_plan_prices for update 
  to authenticated 
  using (public.is_super_admin())
  with check (public.is_super_admin());

create policy "Delete Product Plan Prices" on public.product_plan_prices for delete 
  to authenticated using (public.is_super_admin());

-- Trigger to update updated_at
create trigger handle_updated_at_product_plan_prices
  before update on public.product_plan_prices
  for each row
  execute function moddatetime(updated_at);
