-- ==============================================================================
-- ALLOW ANONYMOUS READ ACCESS FOR PRODUCTS AND PLANS
-- ==============================================================================
-- This migration allows anonymous users to read products and plans
-- This is necessary for the signup flow where users need to see available plans
-- before they are authenticated
-- ==============================================================================

-- Allow anonymous users to read products (for signup flow)
DROP POLICY IF EXISTS "Public Read Products" ON public.products;
CREATE POLICY "Public Read Products" ON public.products 
  FOR SELECT 
  TO authenticated, anon 
  USING (true);

-- Allow anonymous users to read product_plans (for signup flow)
-- Only show active, non-deleted, and public product_plans
-- Note: This updates the existing policy to include anon and filter by status/is_public
DROP POLICY IF EXISTS "Public Read Product Plans" ON public.product_plans;
CREATE POLICY "Public Read Product Plans" ON public.product_plans 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    deleted_at IS NULL
    AND status = true 
    AND (is_public = true OR is_public IS NULL)
  );

-- Allow anonymous users to read plans (for signup flow)
-- Only show non-deleted plans
-- Note: This updates the existing policy to include anon
DROP POLICY IF EXISTS "Public Read Plans" ON public.plans;
CREATE POLICY "Public Read Plans" ON public.plans 
  FOR SELECT 
  TO authenticated, anon 
  USING (deleted_at IS NULL);

COMMENT ON POLICY "Public Read Products" ON public.products IS 
  'Allows authenticated and anonymous users to read products. Necessary for signup flow.';

COMMENT ON POLICY "Public Read Product Plans" ON public.product_plans IS 
  'Allows authenticated and anonymous users to read active, public product_plans. Necessary for signup flow.';

COMMENT ON POLICY "Public Read Plans" ON public.plans IS 
  'Allows authenticated and anonymous users to read non-deleted plans. Necessary for signup flow.';

-- Allow anonymous users to read billing intervals (for signup flow)
DROP POLICY IF EXISTS "Public Read Active Billing Intervals" ON public.billing_intervals;
CREATE POLICY "Public Read Active Billing Intervals" ON public.billing_intervals 
  FOR SELECT 
  TO authenticated, anon 
  USING (is_active = true AND deleted_at IS NULL);

COMMENT ON POLICY "Public Read Active Billing Intervals" ON public.billing_intervals IS 
  'Allows authenticated and anonymous users to read active billing intervals. Necessary for signup flow.';

-- Allow anonymous users to read product_plan_prices (for signup flow)
-- Simplified: only check that product_plan is not deleted
-- The filtering by status/is_public is done at the product_plans level
DROP POLICY IF EXISTS "Public Read Product Plan Prices" ON public.product_plan_prices;
CREATE POLICY "Public Read Product Plan Prices" ON public.product_plan_prices 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    EXISTS (
      SELECT 1 FROM public.product_plans pp 
      WHERE pp.id = product_plan_prices.product_plan_id 
      AND pp.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "Public Read Product Plan Prices" ON public.product_plan_prices IS 
  'Allows authenticated and anonymous users to read product plan prices. Necessary for signup flow.';

-- Allow anonymous users to read plan_entitlements (for signup flow)
DROP POLICY IF EXISTS "Public Read Plan Entitlements" ON public.plan_entitlements;
CREATE POLICY "Public Read Plan Entitlements" ON public.plan_entitlements 
  FOR SELECT 
  TO authenticated, anon 
  USING (true);

COMMENT ON POLICY "Public Read Plan Entitlements" ON public.plan_entitlements IS 
  'Allows authenticated and anonymous users to read plan entitlements. Necessary for signup flow.';

-- Allow anonymous users to read entitlements (for signup flow)
DROP POLICY IF EXISTS "Public Read Entitlements" ON public.entitlements;
CREATE POLICY "Public Read Entitlements" ON public.entitlements 
  FOR SELECT 
  TO authenticated, anon 
  USING (deleted_at IS NULL);

COMMENT ON POLICY "Public Read Entitlements" ON public.entitlements IS 
  'Allows authenticated and anonymous users to read non-deleted entitlements. Necessary for signup flow.';
