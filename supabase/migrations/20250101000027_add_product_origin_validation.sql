-- ==============================================================================
-- ADD PRODUCT ORIGIN URL VALIDATION
-- ==============================================================================
-- This migration adds origin URL validation to products for additional security.
-- The origin URL is validated against the Origin/Referer header from requests.
-- 
-- SECURITY MODEL:
-- - Public endpoints (anon): Require API key + origin validation
-- - Private endpoints (authenticated): Require API key + origin validation + JWT
-- - Super admins: Bypass origin validation (but still require API key and JWT)
-- 
-- IMPORTANT: For automatic header-based validation, you need to configure
-- a PostgREST hook or Supabase Edge Function to extract the Origin/Referer
-- header and set it in the request context as 'request.origin'.
-- ==============================================================================

-- Step 1: Add origin_url column to products table
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS origin_url text;

COMMENT ON COLUMN public.products.origin_url IS 
  'Allowed origin URL for this product (e.g., http://localhost:5174, https://app.example.com). 
   Requests must come from this origin to access product data. NULL means no origin validation.
   Format: protocol://domain[:port] (e.g., http://localhost:5174, https://app.example.com)';

-- Step 2: Create function to validate product origin
CREATE OR REPLACE FUNCTION public.validate_product_origin(
  p_product_id uuid,
  p_origin text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_allowed_origin text;
  v_product_origin_url text;
  v_normalized_origin text;
  v_normalized_allowed text;
BEGIN
  -- Get the product's origin_url
  SELECT origin_url INTO v_product_origin_url
  FROM public.products
  WHERE id = p_product_id
    AND deleted_at IS NULL;
  
  -- If product not found, deny access
  IF v_product_origin_url IS NULL THEN
    RETURN false;
  END IF;
  
  -- If product has no origin_url configured, allow access (backward compatibility)
  IF v_product_origin_url = '' OR v_product_origin_url IS NULL THEN
    RETURN true;
  END IF;
  
  -- Normalize origins for comparison
  -- Remove trailing slashes, convert to lowercase, remove whitespace
  v_normalized_allowed := lower(trim(both '/' from trim(v_product_origin_url)));
  v_normalized_origin := lower(trim(both '/' from trim(coalesce(p_origin, ''))));
  
  -- Compare origins (exact match)
  RETURN v_normalized_allowed = v_normalized_origin;
END;
$$;

COMMENT ON FUNCTION public.validate_product_origin IS 
  'Validates that the provided origin matches the product''s configured origin_url.
   Returns true if origin matches or if product has no origin_url configured.
   Parameters:
   - p_product_id: UUID of the product
   - p_origin: Origin URL from the request header (e.g., http://localhost:5174)';

-- Step 3: Create function to get origin from request context
-- This function attempts to get the origin from the current request context
-- The origin must be set by a PostgREST hook or Supabase Edge Function
CREATE OR REPLACE FUNCTION public.get_request_origin()
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Try to get origin from current_setting (set by middleware/hook)
  -- Returns NULL if not set, which means validation will be skipped for backward compatibility
  RETURN current_setting('request.origin', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.get_request_origin IS 
  'Attempts to get the origin from the current request context.
   Returns NULL if not available. Requires middleware/hook to set request.origin.
   To enable automatic validation, configure a PostgREST hook that extracts
   the Origin or Referer header and sets it as: SET LOCAL request.origin = ''<origin>''';

-- Step 4: Create helper function to validate product origin from context
-- IMPORTANT: Super admins bypass origin validation
CREATE OR REPLACE FUNCTION public.is_product_origin_valid(p_product_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_origin text;
BEGIN
  -- Super admins bypass origin validation
  IF public.is_super_admin() THEN
    RETURN true;
  END IF;
  
  -- Get origin from request context
  v_origin := public.get_request_origin();
  
  -- If origin not available in context, allow access (backward compatibility)
  -- This allows existing products without origin_url to continue working
  -- In production with strict security, you may want to deny if origin is required
  IF v_origin IS NULL THEN
    RETURN true;
  END IF;
  
  -- Validate the origin
  RETURN public.validate_product_origin(p_product_id, v_origin);
END;
$$;

COMMENT ON FUNCTION public.is_product_origin_valid IS 
  'Validates product origin using the origin from request context.
   Returns true if:
   - User is a super admin (bypasses validation)
   - Origin matches the product''s origin_url
   - Product has no origin_url configured (backward compatibility)
   - Origin is not available in context (backward compatibility)
   For automatic validation, ensure request.origin is set by a PostgREST hook.
   Note: Super admins always bypass origin validation.';

-- Step 5: Create function to validate product origin by client_id (for slug-based lookups)
CREATE OR REPLACE FUNCTION public.is_product_origin_valid_by_client_id(
  p_client_id text,
  p_origin text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_product_id uuid;
BEGIN
  -- Get product ID by client_id
  SELECT id INTO v_product_id
  FROM public.products
  WHERE client_id = p_client_id
    AND deleted_at IS NULL;
  
  -- If product not found, deny access
  IF v_product_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Validate origin
  RETURN public.validate_product_origin(v_product_id, p_origin);
END;
$$;

COMMENT ON FUNCTION public.is_product_origin_valid_by_client_id IS 
  'Validates product origin by client_id (slug) instead of UUID.
   Useful for lookups using product client_id.';

-- Step 6: Update RLS policies to include origin validation
-- Note: These policies will work automatically once request.origin is set by a hook
-- For now, they allow access if origin_url is not configured (backward compatibility)

-- Update products policy
DROP POLICY IF EXISTS "Public Read Products" ON public.products;
CREATE POLICY "Public Read Products" ON public.products 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    -- Allow if product has no origin_url configured (backward compatibility)
    origin_url IS NULL 
    OR origin_url = ''
    -- Or if origin validation passes (requires request.origin to be set by hook)
    OR public.is_product_origin_valid(id)
  );

-- Update product_plans policy
DROP POLICY IF EXISTS "Public Read Product Plans" ON public.product_plans;
CREATE POLICY "Public Read Product Plans" ON public.product_plans 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    deleted_at IS NULL
    AND status = true 
    AND (is_public = true OR is_public IS NULL)
    AND (
      -- Allow if product has no origin_url configured (backward compatibility)
      EXISTS (
        SELECT 1 FROM public.products p 
        WHERE p.id = product_plans.product_id 
        AND (p.origin_url IS NULL OR p.origin_url = '')
      )
      -- Or if origin validation passes
      OR public.is_product_origin_valid(product_id)
    )
  );

-- Update product_plan_prices policy
DROP POLICY IF EXISTS "Public Read Product Plan Prices" ON public.product_plan_prices;
CREATE POLICY "Public Read Product Plan Prices" ON public.product_plan_prices 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    EXISTS (
      SELECT 1 FROM public.product_plans pp 
      INNER JOIN public.products p ON p.id = pp.product_id
      WHERE pp.id = product_plan_prices.product_plan_id 
      AND pp.deleted_at IS NULL
      AND (
        -- Allow if product has no origin_url configured (backward compatibility)
        p.origin_url IS NULL 
        OR p.origin_url = ''
        -- Or if origin validation passes (requires request.origin to be set by hook)
        OR public.is_product_origin_valid(p.id)
      )
    )
  );

-- Update plan_entitlements policy to include origin validation
-- Note: This requires getting the product_id from the plan, then from product_plans
DROP POLICY IF EXISTS "Public Read Plan Entitlements" ON public.plan_entitlements;
CREATE POLICY "Public Read Plan Entitlements" ON public.plan_entitlements 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    -- Allow if no product has this plan with origin_url configured (backward compatibility)
    NOT EXISTS (
      SELECT 1 FROM public.product_plans pp
      INNER JOIN public.products p ON p.id = pp.product_id
      WHERE pp.plan_id = plan_entitlements.plan_id
      AND pp.deleted_at IS NULL
      AND p.origin_url IS NOT NULL
      AND p.origin_url != ''
    )
    -- Or if origin validation passes for at least one product using this plan
    OR EXISTS (
      SELECT 1 FROM public.product_plans pp
      INNER JOIN public.products p ON p.id = pp.product_id
      WHERE pp.plan_id = plan_entitlements.plan_id
      AND pp.deleted_at IS NULL
      AND public.is_product_origin_valid(p.id)
    )
  );

COMMENT ON POLICY "Public Read Plan Entitlements" ON public.plan_entitlements IS 
  'Allows authenticated and anonymous users to read plan entitlements with origin validation.
   Super admins bypass origin validation.';

-- Update entitlements policy to include origin validation
-- Note: Entitlements are global, so we validate if ANY product using them has origin_url
DROP POLICY IF EXISTS "Public Read Entitlements" ON public.entitlements;
CREATE POLICY "Public Read Entitlements" ON public.entitlements 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    deleted_at IS NULL
    AND (
      -- Allow if no product using this entitlement has origin_url configured
      NOT EXISTS (
        SELECT 1 FROM public.plan_entitlements pe
        INNER JOIN public.product_plans pp ON pp.plan_id = pe.plan_id
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pe.entitlement_id = entitlements.id
        AND pp.deleted_at IS NULL
        AND p.origin_url IS NOT NULL
        AND p.origin_url != ''
      )
      -- Or if origin validation passes for at least one product using this entitlement
      OR EXISTS (
        SELECT 1 FROM public.plan_entitlements pe
        INNER JOIN public.product_plans pp ON pp.plan_id = pe.plan_id
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pe.entitlement_id = entitlements.id
        AND pp.deleted_at IS NULL
        AND public.is_product_origin_valid(p.id)
      )
    )
  );

COMMENT ON POLICY "Public Read Entitlements" ON public.entitlements IS 
  'Allows authenticated and anonymous users to read non-deleted entitlements with origin validation.
   Super admins bypass origin validation.';

-- Update plans policy to include origin validation
DROP POLICY IF EXISTS "Public Read Plans" ON public.plans;
CREATE POLICY "Public Read Plans" ON public.plans 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    deleted_at IS NULL
    AND (
      -- Allow if no product using this plan has origin_url configured
      NOT EXISTS (
        SELECT 1 FROM public.product_plans pp
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pp.plan_id = plans.id
        AND pp.deleted_at IS NULL
        AND p.origin_url IS NOT NULL
        AND p.origin_url != ''
      )
      -- Or if origin validation passes for at least one product using this plan
      OR EXISTS (
        SELECT 1 FROM public.product_plans pp
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pp.plan_id = plans.id
        AND pp.deleted_at IS NULL
        AND public.is_product_origin_valid(p.id)
      )
    )
  );

COMMENT ON POLICY "Public Read Plans" ON public.plans IS 
  'Allows authenticated and anonymous users to read non-deleted plans with origin validation.
   Super admins bypass origin validation.';

COMMENT ON POLICY "Public Read Products" ON public.products IS 
  'Allows authenticated and anonymous users to read products with origin validation.
   Public endpoints require API key + origin validation.
   Private endpoints require API key + origin validation + JWT.
   Super admins bypass origin validation.';

COMMENT ON POLICY "Public Read Product Plans" ON public.product_plans IS 
  'Allows authenticated and anonymous users to read active, public product_plans with origin validation.
   Super admins bypass origin validation.';

COMMENT ON POLICY "Public Read Product Plan Prices" ON public.product_plan_prices IS 
  'Allows authenticated and anonymous users to read product plan prices with origin validation.
   Super admins bypass origin validation.';

-- Update plan_entitlements policy to include origin validation
-- Note: This requires getting the product_id from the plan, then from product_plans
DROP POLICY IF EXISTS "Public Read Plan Entitlements" ON public.plan_entitlements;
CREATE POLICY "Public Read Plan Entitlements" ON public.plan_entitlements 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    -- Allow if no product has this plan with origin_url configured (backward compatibility)
    NOT EXISTS (
      SELECT 1 FROM public.product_plans pp
      INNER JOIN public.products p ON p.id = pp.product_id
      WHERE pp.plan_id = plan_entitlements.plan_id
      AND pp.deleted_at IS NULL
      AND p.origin_url IS NOT NULL
      AND p.origin_url != ''
    )
    -- Or if origin validation passes for at least one product using this plan
    OR EXISTS (
      SELECT 1 FROM public.product_plans pp
      INNER JOIN public.products p ON p.id = pp.product_id
      WHERE pp.plan_id = plan_entitlements.plan_id
      AND pp.deleted_at IS NULL
      AND public.is_product_origin_valid(p.id)
    )
  );

-- Update entitlements policy to include origin validation
-- Note: Entitlements are global, so we validate if ANY product using them has origin_url
DROP POLICY IF EXISTS "Public Read Entitlements" ON public.entitlements;
CREATE POLICY "Public Read Entitlements" ON public.entitlements 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    deleted_at IS NULL
    AND (
      -- Allow if no product using this entitlement has origin_url configured
      NOT EXISTS (
        SELECT 1 FROM public.plan_entitlements pe
        INNER JOIN public.product_plans pp ON pp.plan_id = pe.plan_id
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pe.entitlement_id = entitlements.id
        AND pp.deleted_at IS NULL
        AND p.origin_url IS NOT NULL
        AND p.origin_url != ''
      )
      -- Or if origin validation passes for at least one product using this entitlement
      OR EXISTS (
        SELECT 1 FROM public.plan_entitlements pe
        INNER JOIN public.product_plans pp ON pp.plan_id = pe.plan_id
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pe.entitlement_id = entitlements.id
        AND pp.deleted_at IS NULL
        AND public.is_product_origin_valid(p.id)
      )
    )
  );

-- Update plans policy to include origin validation
DROP POLICY IF EXISTS "Public Read Plans" ON public.plans;
CREATE POLICY "Public Read Plans" ON public.plans 
  FOR SELECT 
  TO authenticated, anon 
  USING (
    deleted_at IS NULL
    AND (
      -- Allow if no product using this plan has origin_url configured
      NOT EXISTS (
        SELECT 1 FROM public.product_plans pp
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pp.plan_id = plans.id
        AND pp.deleted_at IS NULL
        AND p.origin_url IS NOT NULL
        AND p.origin_url != ''
      )
      -- Or if origin validation passes for at least one product using this plan
      OR EXISTS (
        SELECT 1 FROM public.product_plans pp
        INNER JOIN public.products p ON p.id = pp.product_id
        WHERE pp.plan_id = plans.id
        AND pp.deleted_at IS NULL
        AND public.is_product_origin_valid(p.id)
      )
    )
  );
