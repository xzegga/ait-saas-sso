-- ==============================================================================
-- 020 - RLS ANON + VIEW GRANTS + PRODUCT_PLAN_PRICES/BILLING/EMAIL_TEMPLATES POLICIES
-- ==============================================================================

SET client_min_messages = WARNING;
-- Anon read for signup flow + origin validation when product.origin_urls is set (from original 027)
drop policy if exists "Public Read Products" on public.products;
create policy "Public Read Products" on public.products for select to authenticated, anon
  using (
    (origin_urls is null or cardinality(origin_urls) = 0)
    or (select public.is_product_origin_valid(id))
  );

drop policy if exists "Public Read Product Plans" on public.product_plans;
create policy "Public Read Product Plans" on public.product_plans for select to authenticated, anon
  using (
    deleted_at is null and status = true and (is_public = true or is_public is null)
    and (
      exists (select 1 from public.products p where p.id = product_plans.product_id and (p.origin_urls is null or cardinality(p.origin_urls) = 0))
      or (select public.is_product_origin_valid(product_id))
    )
  );

drop policy if exists "Public Read Plans" on public.plans;
create policy "Public Read Plans" on public.plans for select to authenticated, anon
  using (
    deleted_at is null
    and (
      not exists (
        select 1 from public.product_plans pp
        join public.products p on p.id = pp.product_id
        where pp.plan_id = plans.id and pp.deleted_at is null
          and p.origin_urls is not null and cardinality(p.origin_urls) > 0
      )
      or exists (
        select 1 from public.product_plans pp
        join public.products p on p.id = pp.product_id
        where pp.plan_id = plans.id and pp.deleted_at is null
          and (select public.is_product_origin_valid(p.id))
      )
    )
  );

drop policy if exists "Public Read Active Billing Intervals" on public.billing_intervals;
create policy "Public Read Active Billing Intervals" on public.billing_intervals for select to authenticated, anon
  using (is_active = true and deleted_at is null);

drop policy if exists "Public Read Product Plan Prices" on public.product_plan_prices;
create policy "Public Read Product Plan Prices" on public.product_plan_prices for select to authenticated, anon
  using (
    exists (
      select 1 from public.product_plans pp
      join public.products p on p.id = pp.product_id
      where pp.id = product_plan_prices.product_plan_id and pp.deleted_at is null
        and ((p.origin_urls is null or cardinality(p.origin_urls) = 0) or (select public.is_product_origin_valid(p.id)))
    )
  );

drop policy if exists "Public Read Plan Entitlements" on public.plan_entitlements;
create policy "Public Read Plan Entitlements" on public.plan_entitlements for select to authenticated, anon
  using (
    not exists (
      select 1 from public.product_plans pp
      join public.products p on p.id = pp.product_id
      where pp.plan_id = plan_entitlements.plan_id and pp.deleted_at is null
        and p.origin_urls is not null and cardinality(p.origin_urls) > 0
    )
    or exists (
      select 1 from public.product_plans pp
      join public.products p on p.id = pp.product_id
      where pp.plan_id = plan_entitlements.plan_id and pp.deleted_at is null
        and (select public.is_product_origin_valid(p.id))
    )
  );

drop policy if exists "Public Read Entitlements" on public.entitlements;
create policy "Public Read Entitlements" on public.entitlements for select to authenticated, anon
  using (
    deleted_at is null
    and (
      not exists (
        select 1 from public.plan_entitlements pe
        join public.product_plans pp on pp.plan_id = pe.plan_id
        join public.products p on p.id = pp.product_id
        where pe.entitlement_id = entitlements.id and pp.deleted_at is null
          and p.origin_urls is not null and cardinality(p.origin_urls) > 0
      )
      or exists (
        select 1 from public.plan_entitlements pe
        join public.product_plans pp on pp.plan_id = pe.plan_id
        join public.products p on p.id = pp.product_id
        where pe.entitlement_id = entitlements.id and pp.deleted_at is null
          and (select public.is_product_origin_valid(p.id))
      )
    )
  );
RESET client_min_messages;

-- Product plan prices: super admin Insert/Update/Delete
create policy "Insert Product Plan Prices" on public.product_plan_prices for insert to authenticated
  with check ((select public.is_super_admin()));

create policy "Update Product Plan Prices" on public.product_plan_prices for update to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

create policy "Delete Product Plan Prices" on public.product_plan_prices for delete to authenticated
  using ((select public.is_super_admin()));

-- Billing intervals: super admin full access
create policy "Super Admins Full Access" on public.billing_intervals for all to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

-- Email templates: super admin manage, authenticated/anon read active
create policy "Super admins can manage email templates" on public.email_templates for all to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

create policy "Authenticated users can read active email templates" on public.email_templates for select to authenticated
  using (deleted_at is null and is_active = true);

create policy "Anonymous users can read active email templates" on public.email_templates for select to anon
  using (deleted_at is null and is_active = true);

-- View grants (revoke public/anon, grant authenticated)
revoke all on public.v_subscription_details from public, anon;
grant select on public.v_subscription_details to authenticated;

revoke all on public.v_user_org_roles from public, anon;
grant select on public.v_user_org_roles to authenticated;
