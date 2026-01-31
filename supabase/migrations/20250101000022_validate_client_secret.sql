-- ==============================================================================
-- CLIENT SECRET VALIDATION
-- ==============================================================================
-- Functions and policies to validate client_secret for product authentication
-- ==============================================================================

-- ====================== VALIDATE CLIENT SECRET FUNCTION ======================
-- Function to validate that a client_secret matches a product
-- This function is used by RLS policies and can be called from the SDK
-- Accepts either UUID (product id) or text (client_id)

-- Drop the old function signature if it exists (uuid, text)
DROP FUNCTION IF EXISTS public.validate_client_secret(uuid, text);

-- Create the new function that accepts text (UUID or client_id)
create or replace function public.validate_client_secret(
  p_product_id text,
  p_client_secret text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_valid boolean;
  v_is_uuid boolean;
begin
  -- Check if p_product_id is a valid UUID
  v_is_uuid := p_product_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  
  -- Check if product exists, is active, not deleted, and client_secret matches
  if v_is_uuid then
    -- If it's a UUID, search by id
    select exists (
      select 1
      from public.products
      where id = p_product_id::uuid
        and client_secret = p_client_secret
        and status = true
        and deleted_at is null
    ) into v_is_valid;
  else
    -- If it's not a UUID, search by client_id
    select exists (
      select 1
      from public.products
      where client_id = p_product_id
        and client_secret = p_client_secret
        and status = true
        and deleted_at is null
    ) into v_is_valid;
  end if;
  
  return coalesce(v_is_valid, false);
end;
$$;

comment on function public.validate_client_secret(text, text) is 'Validates that a client_secret matches an active, non-deleted product. Accepts either UUID (product id) or text (client_id). Returns true if valid, false otherwise.';

grant execute on function public.validate_client_secret(text, text) to authenticated;
grant execute on function public.validate_client_secret(text, text) to anon;

-- ====================== GET PRODUCT BY CLIENT SECRET ======================
-- Function to get product information by client_secret (for SDK validation)
-- Returns product_id if valid, null otherwise
create or replace function public.get_product_by_client_secret(
  p_client_secret text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id uuid;
begin
  -- Get product_id for valid client_secret
  select id into v_product_id
  from public.products
  where client_secret = p_client_secret
    and status = true
    and deleted_at is null
  limit 1;
  
  return v_product_id;
end;
$$;

comment on function public.get_product_by_client_secret(text) is 'Returns the product_id for a valid client_secret. Returns null if client_secret is invalid or product is inactive/deleted.';

grant execute on function public.get_product_by_client_secret(text) to authenticated;
grant execute on function public.get_product_by_client_secret(text) to anon;
