-- ==============================================================================
-- BILLING INTERVALS: Configurable billing intervals for pricing
-- ==============================================================================
-- This migration creates a table to store configurable billing intervals
-- (month, year, day, week, etc.) that can be managed by admins instead of
-- being hardcoded in the application.
-- ==============================================================================

create table public.billing_intervals (
  id uuid primary key default gen_random_uuid(),
  key text not null unique, -- e.g. "month", "year", "day", "week"
  label text not null, -- Display label e.g. "Monthly", "Yearly", "Daily", "Weekly"
  description text,
  days integer, -- Number of days this interval represents (for calculations)
  sort_order integer default 0, -- Order for display
  is_active boolean default true not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.billing_intervals is 'Configurable billing intervals for pricing. Admins can manage these instead of hardcoding them.';
comment on column public.billing_intervals.key is 'Unique key identifier (e.g. "month", "year", "day", "week")';
comment on column public.billing_intervals.label is 'Display label for the interval (e.g. "Monthly", "Yearly")';
comment on column public.billing_intervals.days is 'Number of days this interval represents (for calculations and comparisons)';
comment on column public.billing_intervals.sort_order is 'Order for display in dropdowns and lists';

-- Index for faster lookups
create index idx_billing_intervals_key on public.billing_intervals(key);
create index idx_billing_intervals_active on public.billing_intervals(is_active) where deleted_at is null;

-- Enable RLS
alter table public.billing_intervals enable row level security;

-- RLS Policies: Same as other admin-managed tables
create policy "Public Read Active Billing Intervals" on public.billing_intervals for select 
  to authenticated using (is_active = true and deleted_at is null);

create policy "Super Admins Full Access" on public.billing_intervals for all 
  to authenticated using (public.is_super_admin())
  with check (public.is_super_admin());

-- Trigger to update updated_at
create trigger handle_updated_at_billing_intervals
  before update on public.billing_intervals
  for each row
  execute function moddatetime(updated_at);

-- Insert default billing intervals (only month and year)
insert into public.billing_intervals (key, label, description, days, sort_order, is_active) values
  ('month', 'Monthly', 'Billed monthly', 30, 1, true),
  ('year', 'Yearly', 'Billed yearly', 365, 2, true)
  on conflict (key) do nothing;

-- Update product_plan_prices to reference billing_intervals
-- First, add a foreign key constraint (if the table exists)
do $$
begin
  if exists (select 1 from information_schema.tables where table_name = 'product_plan_prices') then
    -- Add foreign key constraint if it doesn't exist
    if not exists (
      select 1 from information_schema.table_constraints 
      where constraint_name = 'product_plan_prices_billing_interval_fkey'
    ) then
      alter table public.product_plan_prices
      add constraint product_plan_prices_billing_interval_fkey
      foreign key (billing_interval) references public.billing_intervals(key);
    end if;
  end if;
end $$;

-- Update payment_prices check constraint to reference billing_intervals
-- Note: We'll keep the check constraint but also add a foreign key for data integrity
do $$
begin
  if exists (select 1 from information_schema.tables where table_name = 'payment_prices') then
    -- Add foreign key constraint if it doesn't exist
    if not exists (
      select 1 from information_schema.table_constraints 
      where constraint_name = 'payment_prices_billing_interval_fkey'
    ) then
      alter table public.payment_prices
      add constraint payment_prices_billing_interval_fkey
      foreign key (billing_interval) references public.billing_intervals(key);
    end if;
  end if;
end $$;
