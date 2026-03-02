-- ==============================================================================
-- 021 - EXTRA INDEXES + FORCE ROW LEVEL SECURITY
-- ==============================================================================

create index if not exists idx_org_members_user_id on public.org_members(user_id);
create index if not exists idx_product_role_definitions_product_id on public.product_role_definitions(product_id);
create index if not exists idx_org_product_subscriptions_plan_id on public.org_product_subscriptions(plan_id);
create index if not exists idx_profiles_deleted_at on public.profiles(deleted_at) where deleted_at is null;

alter table public.profiles force row level security;
alter table public.organizations force row level security;
alter table public.org_members force row level security;
alter table public.org_product_subscriptions force row level security;
alter table public.products force row level security;
alter table public.product_role_definitions force row level security;
alter table public.entitlements force row level security;
alter table public.plans force row level security;
alter table public.plan_entitlements force row level security;
alter table public.product_plans force row level security;
alter table public.member_product_roles force row level security;
alter table public.org_invitations force row level security;
alter table public.super_admins force row level security;
alter table public.role_templates force row level security;
alter table public.recycle_bin force row level security;

alter table public.payment_providers force row level security;
alter table public.payment_accounts force row level security;
alter table public.payment_products force row level security;
alter table public.payment_prices force row level security;
alter table public.payment_subscriptions force row level security;
alter table public.payment_invoices force row level security;
alter table public.payment_webhook_events force row level security;

alter table public.product_plan_prices force row level security;
alter table public.billing_intervals force row level security;
alter table public.email_templates force row level security;
