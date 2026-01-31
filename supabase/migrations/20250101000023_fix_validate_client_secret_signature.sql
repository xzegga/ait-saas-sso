-- ==============================================================================
-- FIX: Update validate_client_secret function signature
-- ==============================================================================
-- This migration fixes the validate_client_secret function to accept text
-- instead of uuid for p_product_id, allowing both UUID and client_id values
-- ==============================================================================

-- Drop the old function signature if it exists (uuid, text)
DROP FUNCTION IF EXISTS public.validate_client_secret(uuid, text);

-- Create the new function that accepts text (UUID or client_id)
CREATE OR REPLACE FUNCTION public.validate_client_secret(
  p_product_id text,
  p_client_secret text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_valid boolean;
  v_is_uuid boolean;
BEGIN
  -- Check if p_product_id is a valid UUID
  v_is_uuid := p_product_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  
  -- Check if product exists, is active, not deleted, and client_secret matches
  IF v_is_uuid THEN
    -- If it's a UUID, search by id
    SELECT EXISTS (
      SELECT 1
      FROM public.products
      WHERE id = p_product_id::uuid
        AND client_secret = p_client_secret
        AND status = true
        AND deleted_at IS NULL
    ) INTO v_is_valid;
  ELSE
    -- If it's not a UUID, search by client_id
    SELECT EXISTS (
      SELECT 1
      FROM public.products
      WHERE client_id = p_product_id
        AND client_secret = p_client_secret
        AND status = true
        AND deleted_at IS NULL
    ) INTO v_is_valid;
  END IF;
  
  RETURN COALESCE(v_is_valid, false);
END;
$$;

-- Update comments and grants
COMMENT ON FUNCTION public.validate_client_secret(text, text) IS 'Validates that a client_secret matches an active, non-deleted product. Accepts either UUID (product id) or text (client_id). Returns true if valid, false otherwise.';

GRANT EXECUTE ON FUNCTION public.validate_client_secret(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_client_secret(text, text) TO anon;
