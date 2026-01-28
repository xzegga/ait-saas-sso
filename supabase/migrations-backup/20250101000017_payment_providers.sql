-- ==============================================================================
-- PAYMENT PROVIDERS - Generic Payment System
-- ==============================================================================
-- This migration creates the payment_providers table to catalog available
-- payment providers (Stripe, PayPal, Razorpay, etc.)
-- ==============================================================================

-- Payment Providers: Catalog of available payment providers
create table public.payment_providers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique, -- Technical identifier: 'stripe', 'paypal', 'razorpay', etc.
  display_name text not null, -- Display name: 'Stripe', 'PayPal', 'Razorpay'
  status text default 'active' check (status in ('active', 'inactive', 'deprecated')),
  config_schema jsonb, -- Schema of required configuration (API keys, webhook URLs, etc.)
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.payment_providers is 'Catalog of available payment providers';
comment on column public.payment_providers.name is 'Technical identifier (e.g., stripe, paypal, razorpay)';
comment on column public.payment_providers.display_name is 'Display name for UI (e.g., Stripe, PayPal, Razorpay)';
comment on column public.payment_providers.status is 'Provider status: active, inactive, or deprecated';
comment on column public.payment_providers.config_schema is 'JSON schema defining required configuration fields';

-- Indexes
create index idx_payment_providers_name on public.payment_providers(name);
create index idx_payment_providers_status on public.payment_providers(status);

-- Enable RLS
alter table public.payment_providers enable row level security;

-- Initial data: Insert Stripe as default provider
insert into public.payment_providers (name, display_name, status, config_schema) values
(
  'stripe',
  'Stripe',
  'active',
  '{
    "required": ["api_key", "webhook_secret"],
    "optional": ["api_version"],
    "fields": {
      "api_key": {
        "type": "string",
        "description": "Stripe API key (sk_live_xxx or sk_test_xxx)"
      },
      "webhook_secret": {
        "type": "string",
        "description": "Stripe webhook signing secret (whsec_xxx)"
      },
      "api_version": {
        "type": "string",
        "description": "Stripe API version (optional, defaults to latest)"
      }
    }
  }'::jsonb
);
