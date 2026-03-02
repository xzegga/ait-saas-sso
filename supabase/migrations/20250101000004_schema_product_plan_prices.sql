-- ==============================================================================
-- 004 - PRODUCT PLAN PRICES (multiple prices per product_plan per billing interval)
-- ==============================================================================

create table public.product_plan_prices (
  id uuid primary key default gen_random_uuid(),
  product_plan_id uuid references public.product_plans(id) on delete cascade not null,
  billing_interval text not null references public.billing_intervals(key) on update cascade,
  price decimal(10, 2) not null,
  currency text default 'USD' not null,
  is_default boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(product_plan_id, billing_interval)
);

comment on table public.product_plan_prices is 'Stores multiple prices per product_plan based on billing intervals (month, year, day, week).';
comment on column public.product_plan_prices.billing_interval is 'Billing interval key (references billing_intervals.key).';
comment on column public.product_plan_prices.price is 'Price for this billing interval.';
comment on column public.product_plan_prices.is_default is 'If true, this is the default price to show when no interval is specified.';

create index idx_product_plan_prices_product_plan_id on public.product_plan_prices(product_plan_id);
create index idx_product_plan_prices_billing_interval on public.product_plan_prices(billing_interval);

alter table public.product_plan_prices enable row level security;

create trigger handle_updated_at_product_plan_prices
  before update on public.product_plan_prices
  for each row
  execute function moddatetime(updated_at);
