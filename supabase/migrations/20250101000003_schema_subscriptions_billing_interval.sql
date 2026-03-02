-- ==============================================================================
-- 003 - ADD BILLING INTERVAL TO ORG PRODUCT SUBSCRIPTIONS
-- ==============================================================================

alter table public.org_product_subscriptions
  add column if not exists billing_interval_id text references public.billing_intervals(key) on update cascade;

comment on column public.org_product_subscriptions.billing_interval_id is 'Billing interval key (references billing_intervals.key). Defines the billing period for this subscription.';

create index if not exists idx_subscriptions_billing_interval on public.org_product_subscriptions(billing_interval_id) where billing_interval_id is not null;
