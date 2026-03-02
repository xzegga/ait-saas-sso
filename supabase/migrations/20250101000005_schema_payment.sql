-- ==============================================================================
-- 005 - PAYMENT TABLES (generic payment system)
-- ==============================================================================
-- Providers -> Accounts -> Products -> Prices -> Subscriptions -> Invoices -> Webhook Events
-- payment_prices: unique per (product_plan_id, provider_id, billing_interval), FK to billing_intervals
-- ==============================================================================

create table public.payment_providers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  display_name text not null,
  status text default 'active' check (status in ('active', 'inactive', 'deprecated')),
  config_schema jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.payment_providers is 'Catalog of available payment providers';
comment on column public.payment_providers.name is 'Technical identifier (e.g., stripe, paypal, razorpay)';
comment on column public.payment_providers.display_name is 'Display name for UI (e.g., Stripe, PayPal, Razorpay)';

create index idx_payment_providers_name on public.payment_providers(name);
create index idx_payment_providers_status on public.payment_providers(status);

insert into public.payment_providers (name, display_name, status, config_schema) values
(
  'stripe',
  'Stripe',
  'active',
  '{"required": ["api_key", "webhook_secret"], "optional": ["api_version"], "fields": {"api_key": {"type": "string", "description": "Stripe API key (sk_live_xxx or sk_test_xxx)"}, "webhook_secret": {"type": "string", "description": "Stripe webhook signing secret (whsec_xxx)"}, "api_version": {"type": "string", "description": "Stripe API version (optional)"}}}'::jsonb
);

create table public.payment_accounts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_account_id text not null,
  email text,
  metadata jsonb default '{}'::jsonb,
  status text default 'active' check (status in ('active', 'inactive', 'suspended')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(org_id, provider_id),
  unique(provider_id, external_account_id)
);

comment on table public.payment_accounts is 'Generic payment accounts linking organizations to provider accounts.';

create table public.payment_products (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_product_id text not null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(product_id, provider_id)
);

comment on table public.payment_products is 'Generic products mapping internal products to provider products.';

create table public.payment_prices (
  id uuid primary key default gen_random_uuid(),
  product_plan_id uuid references public.product_plans(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_price_id text not null,
  external_product_id text not null,
  billing_interval text references public.billing_intervals(key) on update cascade,
  currency text default 'usd',
  amount bigint,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(product_plan_id, provider_id, billing_interval)
);

comment on table public.payment_prices is 'Generic prices mapping internal plans to provider prices. One row per (plan, provider, billing_interval).';
comment on column public.payment_prices.billing_interval is 'Billing interval key (references billing_intervals.key).';

create table public.payment_subscriptions (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.org_product_subscriptions(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  payment_account_id uuid references public.payment_accounts(id) on delete cascade not null,
  external_subscription_id text not null unique,
  external_price_id text not null,
  status text not null,
  provider_status text not null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  canceled_at timestamptz,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(subscription_id, provider_id)
);

comment on table public.payment_subscriptions is 'Generic subscriptions mapping internal subscriptions to provider subscriptions.';

create table public.payment_invoices (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  payment_account_id uuid references public.payment_accounts(id) on delete set null,
  payment_subscription_id uuid references public.payment_subscriptions(id) on delete set null,
  org_id uuid references public.organizations(id) on delete set null,
  external_invoice_id text not null unique,
  amount_due bigint not null,
  amount_paid bigint default 0,
  currency text default 'usd',
  status text not null,
  provider_status text not null,
  invoice_pdf text,
  hosted_invoice_url text,
  period_start timestamptz,
  period_end timestamptz,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.payment_invoices is 'Generic invoices from payment providers.';

create table public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_event_id text not null,
  event_type text not null,
  provider_event_type text not null,
  processed boolean default false,
  processed_at timestamptz,
  event_data jsonb not null,
  error_message text,
  created_at timestamptz default now(),
  unique(provider_id, external_event_id)
);

comment on table public.payment_webhook_events is 'Generic webhook events log from all payment providers.';

-- Indexes
create index idx_payment_accounts_org_id on public.payment_accounts(org_id);
create index idx_payment_accounts_provider_id on public.payment_accounts(provider_id);
create index idx_payment_accounts_external_id on public.payment_accounts(provider_id, external_account_id);
create index idx_payment_products_product_id on public.payment_products(product_id);
create index idx_payment_products_provider_id on public.payment_products(provider_id);
create index idx_payment_products_external_id on public.payment_products(provider_id, external_product_id);
create index idx_payment_prices_product_plan_id on public.payment_prices(product_plan_id);
create index idx_payment_prices_provider_id on public.payment_prices(provider_id);
create index idx_payment_prices_external_id on public.payment_prices(provider_id, external_price_id);
create index idx_payment_subscriptions_subscription_id on public.payment_subscriptions(subscription_id);
create index idx_payment_subscriptions_provider_id on public.payment_subscriptions(provider_id);
create index idx_payment_subscriptions_account_id on public.payment_subscriptions(payment_account_id);
create index idx_payment_subscriptions_external_id on public.payment_subscriptions(external_subscription_id);
create index idx_payment_subscriptions_status on public.payment_subscriptions(status);
create index idx_payment_invoices_provider_id on public.payment_invoices(provider_id);
create index idx_payment_invoices_account_id on public.payment_invoices(payment_account_id);
create index idx_payment_invoices_subscription_id on public.payment_invoices(payment_subscription_id);
create index idx_payment_invoices_org_id on public.payment_invoices(org_id);
create index idx_payment_invoices_external_id on public.payment_invoices(external_invoice_id);
create index idx_payment_invoices_status on public.payment_invoices(status);
create index idx_payment_webhook_events_provider_id on public.payment_webhook_events(provider_id);
create index idx_payment_webhook_events_external_id on public.payment_webhook_events(provider_id, external_event_id);
create index idx_payment_webhook_events_processed on public.payment_webhook_events(processed);
create index idx_payment_webhook_events_event_type on public.payment_webhook_events(event_type);

alter table public.payment_providers enable row level security;
alter table public.payment_accounts enable row level security;
alter table public.payment_products enable row level security;
alter table public.payment_prices enable row level security;
alter table public.payment_subscriptions enable row level security;
alter table public.payment_invoices enable row level security;
alter table public.payment_webhook_events enable row level security;
