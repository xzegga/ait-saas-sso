-- ==============================================================================
-- FIX PRODUCT PLAN PRICES BILLING INTERVAL CONSTRAINT
-- ==============================================================================
-- This migration replaces the hardcoded CHECK constraint on billing_interval
-- with a foreign key reference to the dynamic billing_intervals table.
-- This allows admins to create custom billing intervals (e.g., "two_years")
-- without modifying the database schema.
-- ==============================================================================

-- Remove the old CHECK constraint
alter table public.product_plan_prices
drop constraint if exists product_plan_prices_billing_interval_check;

-- Add foreign key constraint to billing_intervals (if it doesn't already exist)
-- Note: This was already added in migration 20250101000016, but we ensure it exists
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints 
    where constraint_name = 'product_plan_prices_billing_interval_fkey'
    and table_name = 'product_plan_prices'
  ) then
    alter table public.product_plan_prices
    add constraint product_plan_prices_billing_interval_fkey
    foreign key (billing_interval) references public.billing_intervals(key) on update cascade;
  end if;
end $$;

-- Update comment to reflect the change
comment on column public.product_plan_prices.billing_interval is 'Billing interval key (references billing_intervals.key). Can be any value defined in billing_intervals table.';
