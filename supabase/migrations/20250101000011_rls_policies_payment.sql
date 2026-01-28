-- ==============================================================================
-- PAYMENT RLS POLICIES - Generic Payment System
-- ==============================================================================
-- Row Level Security policies for payment tables
-- ==============================================================================

-- ====================== PAYMENT PROVIDERS ======================
-- Payment Providers: Only super admins can manage
create policy "Super admins can view all payment providers"
  on public.payment_providers
  for select
  using (public.is_super_admin());

create policy "Super admins can insert payment providers"
  on public.payment_providers
  for insert
  with check (public.is_super_admin());

create policy "Super admins can update payment providers"
  on public.payment_providers
  for update
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ====================== PAYMENT ACCOUNTS ======================
-- Payment Accounts: Super admins can view all, org admins can view their org's accounts
create policy "Super admins can view all payment accounts"
  on public.payment_accounts
  for select
  using (public.is_super_admin());

create policy "Org admins can view their org payment accounts"
  on public.payment_accounts
  for select
  using (
    org_id is not null
    and exists (
      select 1
      from public.org_members om
      where om.org_id = payment_accounts.org_id
        and om.user_id = auth.uid()
        and om.status = 'active'
        and (select prd.role_name from public.member_product_roles mpr
             join public.product_role_definitions prd on mpr.role_definition_id = prd.id
             join public.org_members om2 on mpr.member_id = om2.id
             where om2.user_id = auth.uid()
               and om2.org_id = om.org_id
             limit 1) in ('Owner', 'Admin')
    )
  );

create policy "Super admins can insert payment accounts"
  on public.payment_accounts
  for insert
  with check (public.is_super_admin());

create policy "Super admins can update payment accounts"
  on public.payment_accounts
  for update
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ====================== PAYMENT PRODUCTS ======================
-- Payment Products: Only super admins can manage
create policy "Super admins can view all payment products"
  on public.payment_products
  for select
  using (public.is_super_admin());

create policy "Super admins can insert payment products"
  on public.payment_products
  for insert
  with check (public.is_super_admin());

create policy "Super admins can update payment products"
  on public.payment_products
  for update
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ====================== PAYMENT PRICES ======================
-- Payment Prices: Only super admins can manage
create policy "Super admins can view all payment prices"
  on public.payment_prices
  for select
  using (public.is_super_admin());

create policy "Super admins can insert payment prices"
  on public.payment_prices
  for insert
  with check (public.is_super_admin());

create policy "Super admins can update payment prices"
  on public.payment_prices
  for update
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ====================== PAYMENT SUBSCRIPTIONS ======================
-- Payment Subscriptions: Super admins can view all, org admins can view their org's subscriptions
create policy "Super admins can view all payment subscriptions"
  on public.payment_subscriptions
  for select
  using (public.is_super_admin());

create policy "Org admins can view their org payment subscriptions"
  on public.payment_subscriptions
  for select
  using (
    exists (
      select 1
      from public.org_product_subscriptions ops
      join public.org_members om on ops.org_id = om.org_id
      where ops.id = payment_subscriptions.subscription_id
        and om.user_id = auth.uid()
        and om.status = 'active'
        and (select prd.role_name from public.member_product_roles mpr
             join public.product_role_definitions prd on mpr.role_definition_id = prd.id
             join public.org_members om2 on mpr.member_id = om2.id
             where om2.user_id = auth.uid()
               and om2.org_id = ops.org_id
             limit 1) in ('Owner', 'Admin')
    )
  );

create policy "Super admins can insert payment subscriptions"
  on public.payment_subscriptions
  for insert
  with check (public.is_super_admin());

create policy "Super admins can update payment subscriptions"
  on public.payment_subscriptions
  for update
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ====================== PAYMENT INVOICES ======================
-- Payment Invoices: Super admins can view all, org admins can view their org's invoices
create policy "Super admins can view all payment invoices"
  on public.payment_invoices
  for select
  using (public.is_super_admin());

create policy "Org admins can view their org payment invoices"
  on public.payment_invoices
  for select
  using (
    org_id is not null
    and exists (
      select 1
      from public.org_members om
      where om.org_id = payment_invoices.org_id
        and om.user_id = auth.uid()
        and om.status = 'active'
        and (select prd.role_name from public.member_product_roles mpr
             join public.product_role_definitions prd on mpr.role_definition_id = prd.id
             join public.org_members om2 on mpr.member_id = om2.id
             where om2.user_id = auth.uid()
               and om2.org_id = om.org_id
             limit 1) in ('Owner', 'Admin')
    )
  );

create policy "Service role can insert payment invoices"
  on public.payment_invoices
  for insert
  with check (true); -- Webhook handler will use service role

create policy "Service role can update payment invoices"
  on public.payment_invoices
  for update
  using (true)
  with check (true); -- Webhook handler will use service role

-- ====================== PAYMENT WEBHOOK EVENTS ======================
-- Payment Webhook Events: Only super admins can view (for debugging)
create policy "Super admins can view all payment webhook events"
  on public.payment_webhook_events
  for select
  using (public.is_super_admin());

create policy "Service role can insert payment webhook events"
  on public.payment_webhook_events
  for insert
  with check (true); -- Webhook handler will use service role

create policy "Service role can update payment webhook events"
  on public.payment_webhook_events
  for update
  using (true)
  with check (true); -- Webhook handler will use service role
