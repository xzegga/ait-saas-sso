-- ==============================================================================
-- PAYMENT TABLES - Generic Payment System
-- ==============================================================================
-- This migration creates generic payment tables that work with any payment provider
-- ==============================================================================

-- Payment Accounts: Generic payment accounts (maps organizations to provider accounts)
create table public.payment_accounts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_account_id text not null, -- Provider's customer/account ID (e.g., 'cus_xxx' for Stripe, 'customer_xxx' for PayPal)
  email text, -- Billing email
  metadata jsonb default '{}'::jsonb, -- Provider-specific data (payment methods, tax IDs, etc.)
  status text default 'active' check (status in ('active', 'inactive', 'suspended')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(org_id, provider_id), -- One account per provider per organization
  unique(provider_id, external_account_id) -- External ID must be unique per provider
);

comment on table public.payment_accounts is 'Generic payment accounts linking organizations to provider accounts';
comment on column public.payment_accounts.external_account_id is 'Provider-specific account ID (e.g., cus_xxx for Stripe)';
comment on column public.payment_accounts.metadata is 'Provider-specific data stored as JSONB';

-- Payment Products: Generic products in payment providers
create table public.payment_products (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_product_id text not null, -- Provider's product ID (e.g., 'prod_xxx' for Stripe)
  metadata jsonb default '{}'::jsonb, -- Provider-specific product data
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(product_id, provider_id) -- One product per provider
);

comment on table public.payment_products is 'Generic products mapping internal products to provider products';
comment on column public.payment_products.external_product_id is 'Provider-specific product ID (e.g., prod_xxx for Stripe)';
comment on column public.payment_products.metadata is 'Provider-specific product data stored as JSONB';

-- Payment Prices: Generic prices in payment providers
create table public.payment_prices (
  id uuid primary key default gen_random_uuid(),
  product_plan_id uuid references public.product_plans(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_price_id text not null, -- Provider's price ID (e.g., 'price_xxx' for Stripe)
  external_product_id text not null, -- Reference to provider product
  billing_interval text check (billing_interval in ('month', 'year', 'day', 'week')),
  currency text default 'usd',
  amount bigint, -- Amount in cents/smallest currency unit
  metadata jsonb default '{}'::jsonb, -- Provider-specific price data
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(product_plan_id, provider_id) -- One price per plan per provider
);

comment on table public.payment_prices is 'Generic prices mapping internal plans to provider prices';
comment on column public.payment_prices.external_price_id is 'Provider-specific price ID (e.g., price_xxx for Stripe)';
comment on column public.payment_prices.amount is 'Amount in cents or smallest currency unit';
comment on column public.payment_prices.metadata is 'Provider-specific price data stored as JSONB';

-- Payment Subscriptions: Generic subscriptions in payment providers
create table public.payment_subscriptions (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.org_product_subscriptions(id) on delete cascade not null,
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  payment_account_id uuid references public.payment_accounts(id) on delete cascade not null,
  external_subscription_id text not null unique, -- Provider's subscription ID (e.g., 'sub_xxx' for Stripe)
  external_price_id text not null, -- Reference to provider price
  status text not null, -- Normalized status: 'active', 'trial', 'past_due', 'canceled', 'incomplete'
  provider_status text not null, -- Original provider status (for debugging)
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  canceled_at timestamptz,
  metadata jsonb default '{}'::jsonb, -- Provider-specific subscription data
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(subscription_id, provider_id) -- One subscription per provider
);

comment on table public.payment_subscriptions is 'Generic subscriptions mapping internal subscriptions to provider subscriptions';
comment on column public.payment_subscriptions.external_subscription_id is 'Provider-specific subscription ID (e.g., sub_xxx for Stripe)';
comment on column public.payment_subscriptions.status is 'Normalized status for cross-provider compatibility';
comment on column public.payment_subscriptions.provider_status is 'Original provider status for debugging and provider-specific logic';
comment on column public.payment_subscriptions.metadata is 'Provider-specific subscription data stored as JSONB';

-- Payment Invoices: Generic invoices from payment providers
create table public.payment_invoices (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  payment_account_id uuid references public.payment_accounts(id) on delete set null,
  payment_subscription_id uuid references public.payment_subscriptions(id) on delete set null,
  org_id uuid references public.organizations(id) on delete set null,
  external_invoice_id text not null unique, -- Provider's invoice ID (e.g., 'in_xxx' for Stripe)
  amount_due bigint not null, -- Amount in cents/smallest currency unit
  amount_paid bigint default 0, -- Amount paid in cents/smallest currency unit
  currency text default 'usd',
  status text not null, -- Normalized status: 'draft', 'open', 'paid', 'void', 'uncollectible'
  provider_status text not null, -- Original provider status
  invoice_pdf text, -- URL to invoice PDF
  hosted_invoice_url text, -- URL to hosted invoice page
  period_start timestamptz,
  period_end timestamptz,
  metadata jsonb default '{}'::jsonb, -- Provider-specific invoice data
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.payment_invoices is 'Generic invoices from payment providers';
comment on column public.payment_invoices.external_invoice_id is 'Provider-specific invoice ID (e.g., in_xxx for Stripe)';
comment on column public.payment_invoices.amount_due is 'Amount due in cents or smallest currency unit';
comment on column public.payment_invoices.amount_paid is 'Amount paid in cents or smallest currency unit';
comment on column public.payment_invoices.status is 'Normalized status for cross-provider compatibility';
comment on column public.payment_invoices.provider_status is 'Original provider status for debugging';
comment on column public.payment_invoices.metadata is 'Provider-specific invoice data stored as JSONB';

-- Payment Webhook Events: Generic webhook events log
create table public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.payment_providers(id) on delete cascade not null,
  external_event_id text not null, -- Provider's event ID (e.g., 'evt_xxx' for Stripe)
  event_type text not null, -- Normalized event type (e.g., 'subscription.created', 'invoice.paid')
  provider_event_type text not null, -- Original provider event type (e.g., 'customer.subscription.created' for Stripe)
  processed boolean default false, -- Whether the event has been processed
  processed_at timestamptz,
  event_data jsonb not null, -- Full webhook payload
  error_message text, -- Error message if processing failed
  created_at timestamptz default now(),
  unique(provider_id, external_event_id) -- Event ID must be unique per provider
);

comment on table public.payment_webhook_events is 'Generic webhook events log from all payment providers';
comment on column public.payment_webhook_events.external_event_id is 'Provider-specific event ID (e.g., evt_xxx for Stripe)';
comment on column public.payment_webhook_events.event_type is 'Normalized event type for cross-provider compatibility';
comment on column public.payment_webhook_events.provider_event_type is 'Original provider event type for debugging';
comment on column public.payment_webhook_events.event_data is 'Full webhook payload stored as JSONB';

-- Indexes for performance
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

-- Enable RLS on all tables
alter table public.payment_accounts enable row level security;
alter table public.payment_products enable row level security;
alter table public.payment_prices enable row level security;
alter table public.payment_subscriptions enable row level security;
alter table public.payment_invoices enable row level security;
alter table public.payment_webhook_events enable row level security;
