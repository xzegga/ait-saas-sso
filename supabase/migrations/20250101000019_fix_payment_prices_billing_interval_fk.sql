-- ==============================================================================
-- FIX PAYMENT PRICES BILLING INTERVAL CONSTRAINT
-- ==============================================================================
-- This migration replaces the hardcoded CHECK constraint on billing_interval
-- in payment_prices with a foreign key reference to the dynamic billing_intervals table.
-- This allows admins to create custom billing intervals that can be used in payment providers.
-- ==============================================================================

-- Remove the old CHECK constraint if it exists
alter table public.payment_prices
drop constraint if exists payment_prices_billing_interval_check;

-- Add foreign key constraint to billing_intervals (if it doesn't already exist)
-- Note: This was already added in migration 20250101000016, but we ensure it exists
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints 
    where constraint_name = 'payment_prices_billing_interval_fkey'
    and table_name = 'payment_prices'
  ) then
    alter table public.payment_prices
    add constraint payment_prices_billing_interval_fkey
    foreign key (billing_interval) references public.billing_intervals(key) on update cascade;
  end if;
end $$;

-- Update comment to reflect the change
comment on column public.payment_prices.billing_interval is 'Billing interval key (references billing_intervals.key). Can be any value defined in billing_intervals table.';
