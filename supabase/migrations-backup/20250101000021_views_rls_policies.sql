-- ==============================================================================
-- VIEWS RLS POLICIES
-- ==============================================================================
-- Row Level Security for database views
-- ==============================================================================
-- Note: PostgreSQL views cannot have RLS policies directly. Views inherit RLS
-- from their underlying tables. We restrict access by:
-- 1. Revoking public/anon access
-- 2. Granting access only to authenticated users
-- 3. The underlying table RLS policies will filter the results
-- 
-- For views that should be super-admin only, we rely on the RLS policies
-- of the underlying tables (organizations, org_product_subscriptions, etc.)
-- which already restrict access appropriately.

-- ====================== V_SUBSCRIPTION_DETAILS ======================
-- This view shows complete subscription information including organization,
-- product, plan, pricing, and trial details. 
-- 
-- Security: The view inherits RLS from underlying tables:
-- - organizations: Only super admins can see all orgs
-- - org_product_subscriptions: Only super admins can see all subscriptions
-- - products, plans: Public read (but filtered by deleted_at)
--
-- Since this view joins across multiple tables, users will only see data
-- from organizations they have access to (via RLS on organizations table).

-- Revoke public and anon access
revoke all on public.v_subscription_details from public;
revoke all on public.v_subscription_details from anon;

-- Keep access for authenticated users (RLS from underlying tables will filter)
grant select on public.v_subscription_details to authenticated;

comment on view public.v_subscription_details is 
  'Complete subscription information. Access is restricted by RLS policies on underlying tables. Only super admins can see all organizations'' subscriptions.';

-- ====================== V_USER_ORG_ROLES ======================
-- This view is for debugging user roles across organizations.
-- Should only be accessible to super admins as it contains sensitive
-- user and organization relationship information.
--
-- Security: The view inherits RLS from underlying tables:
-- - org_members: Only super admins can see all members
-- - organizations: Only super admins can see all orgs
-- - member_product_roles: Filtered by org access

-- Revoke public and anon access
revoke all on public.v_user_org_roles from public;
revoke all on public.v_user_org_roles from anon;

-- Keep access for authenticated users (RLS from underlying tables will filter)
grant select on public.v_user_org_roles to authenticated;

comment on view public.v_user_org_roles is 
  'User-organization-role relationships for debugging. Access is restricted by RLS policies on underlying tables. Only super admins can see all relationships.';
