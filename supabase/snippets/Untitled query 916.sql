-- ==============================================================================
-- 026 - ORGANIZATIONS EXTRA FIELDS (slug, legal, status, contact, billing address)
-- ==============================================================================

-- Slug: stable identifier for URLs/APIs (unique, nullable for existing rows)
alter table public.organizations
  add column if not exists slug text unique;

comment on column public.organizations.slug is 'URL-safe unique identifier for the organization (e.g. acme-corp). Used in APIs and stable links.';

-- Legal / billing
alter table public.organizations
  add column if not exists legal_name text,
  add column if not exists tax_id text;

comment on column public.organizations.legal_name is 'Legal or registered company name for contracts and invoices.';
comment on column public.organizations.tax_id is 'Tax identifier (VAT, NIF, EIN, etc.) for billing and compliance.';

-- Status: activate/suspend without soft delete
alter table public.organizations
  add column if not exists status text not null default 'active'
    check (status in ('active', 'suspended', 'trial'));

comment on column public.organizations.status is 'Organization status: active (normal), suspended (access disabled), trial.';

-- Support and contact
alter table public.organizations
  add column if not exists support_email text,
  add column if not exists phone text;

comment on column public.organizations.support_email is 'Support or general contact email for the organization.';
comment on column public.organizations.phone is 'Primary contact phone number.';

-- Billing address (separate fields for clarity and indexing)
alter table public.organizations
  add column if not exists billing_street text,
  add column if not exists billing_address_line2 text,
  add column if not exists billing_city text,
  add column if not exists billing_postal_code text,
  add column if not exists billing_country text;

comment on column public.organizations.billing_street is 'Street address line 1 for billing/invoices.';
comment on column public.organizations.billing_address_line2 is 'Street address line 2 (floor, suite, etc.).';
comment on column public.organizations.billing_city is 'City for billing address.';
comment on column public.organizations.billing_postal_code is 'Postal/ZIP code for billing address.';
comment on column public.organizations.billing_country is 'Country code or name for billing address.';

-- Index for filtering by status (e.g. list active orgs)
create index if not exists idx_organizations_status on public.organizations(status) where deleted_at is null;
