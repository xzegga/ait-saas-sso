-- ==============================================================================
-- 002 - BILLING INTERVALS (configurable billing periods for pricing)
-- ==============================================================================

create table public.billing_intervals (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  label text not null,
  description text,
  days integer,
  sort_order integer default 0,
  is_active boolean default true not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz default null
);

comment on table public.billing_intervals is 'Configurable billing intervals for pricing. Admins can manage these instead of hardcoding them.';
comment on column public.billing_intervals.key is 'Unique key identifier (e.g. "month", "year")';
comment on column public.billing_intervals.label is 'Display label for the interval (e.g. "Monthly", "Yearly")';
comment on column public.billing_intervals.days is 'Number of days this interval represents (for calculations and comparisons)';
comment on column public.billing_intervals.sort_order is 'Order for display in dropdowns and lists';

create index idx_billing_intervals_key on public.billing_intervals(key);
create index idx_billing_intervals_active on public.billing_intervals(is_active) where deleted_at is null;

alter table public.billing_intervals enable row level security;

create trigger handle_updated_at_billing_intervals
  before update on public.billing_intervals
  for each row
  execute function moddatetime(updated_at);

-- Seed: only month and year (no day/week per product decision)
insert into public.billing_intervals (key, label, description, days, sort_order, is_active) values
  ('month', 'Monthly', 'Billed monthly', 30, 1, true),
  ('year', 'Yearly', 'Billed yearly', 365, 2, true)
  on conflict (key) do nothing;
