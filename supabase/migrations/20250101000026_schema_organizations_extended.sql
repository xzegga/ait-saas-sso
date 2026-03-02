-- ==============================================================================
-- 026 - ORGANIZATIONS EXTENDED (slug, legal_name, tax_id, status, support_email, phone)
--       + ORGANIZATION_ADDRESSES (addresses by type: billing, shipping, legal, etc.)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- Organizations: new columns
-- -----------------------------------------------------------------------------
alter table public.organizations
  add column if not exists slug text,
  add column if not exists legal_name text,
  add column if not exists tax_id text,
  add column if not exists status text not null default 'active',
  add column if not exists support_email text,
  add column if not exists phone text;

-- Unique slug (multiple nulls allowed in PostgreSQL)
create unique index if not exists idx_organizations_slug on public.organizations(slug) where slug is not null;

alter table public.organizations
  add constraint organizations_status_check check (status in ('active', 'suspended', 'inactive'));

comment on column public.organizations.slug is 'Stable identifier for URLs and APIs (e.g. acme-corp). Unique when set.';
comment on column public.organizations.legal_name is 'Legal / registered company name for contracts and invoices.';
comment on column public.organizations.tax_id is 'Tax identifier (VAT, NIF, EIN, etc.) for billing.';
comment on column public.organizations.status is 'Organization status: active, suspended, or inactive. Used to enable/disable without soft delete.';
comment on column public.organizations.support_email is 'Support or primary contact email.';
comment on column public.organizations.phone is 'Primary contact phone number.';

-- -----------------------------------------------------------------------------
-- Organization addresses: one row per (org, address_type)
-- -----------------------------------------------------------------------------
create table public.organization_addresses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  address_type text not null,
  line1 text,
  line2 text,
  city text,
  state_region text,
  postal_code text,
  country_code text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(org_id, address_type),
  constraint organization_addresses_type_check check (
    address_type in ('billing', 'shipping', 'legal', 'headquarters')
  )
);

comment on table public.organization_addresses is 'Addresses for organizations, classified by type (billing, shipping, legal, headquarters).';
comment on column public.organization_addresses.address_type is 'Type of address: billing, shipping, legal, headquarters.';
comment on column public.organization_addresses.country_code is 'ISO 3166-1 alpha-2 country code (e.g. ES, US).';

create index if not exists idx_organization_addresses_org_id on public.organization_addresses(org_id);
create index if not exists idx_organization_addresses_org_type on public.organization_addresses(org_id, address_type);

-- Automatic updated_at
create trigger handle_organization_addresses_updated_at
  before update on public.organization_addresses
  for each row execute procedure moddatetime(updated_at);

-- -----------------------------------------------------------------------------
-- RLS for organization_addresses (same pattern as organizations)
-- -----------------------------------------------------------------------------
alter table public.organization_addresses enable row level security;

create policy "Select organization_addresses" on public.organization_addresses for select to authenticated
  using (
    (select public.is_super_admin())
    or org_id = (select public.get_my_org_id())
  );

create policy "Insert organization_addresses" on public.organization_addresses for insert to authenticated
  with check (
    (select public.is_super_admin())
    or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner')
  );

create policy "Update organization_addresses" on public.organization_addresses for update to authenticated
  using (
    (select public.is_super_admin())
    or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner')
  )
  with check (
    (select public.is_super_admin())
    or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner')
  );

create policy "Delete organization_addresses" on public.organization_addresses for delete to authenticated
  using (
    (select public.is_super_admin())
    or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner')
  );

alter table public.organization_addresses force row level security;
