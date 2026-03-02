-- ==============================================================================
-- 013 - VALIDATE CLIENT SECRET & GET PRODUCT BY CLIENT SECRET
-- ==============================================================================

SET client_min_messages = WARNING;
DROP FUNCTION IF EXISTS public.validate_client_secret(uuid, text);
DROP FUNCTION IF EXISTS public.validate_client_secret(text, text);
DROP FUNCTION IF EXISTS public.validate_client_secret(text, text, text);
RESET client_min_messages;

-- Origin is read from request headers (Origin/Referer) by get_request_origin(), not sent by client.
-- Requires PostgREST/Supabase to pass request headers into the session (e.g. db-pre-request calling extract_request_origin).
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
  v_is_uuid boolean;
  v_product_id uuid;
  v_origin_urls text[];
  v_origin text;
begin
  v_is_uuid := p_product_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  if v_is_uuid then
    select id, origin_urls into v_product_id, v_origin_urls
    from public.products
    where id = p_product_id::uuid and client_secret = p_client_secret and status = true and deleted_at is null;
  else
    select id, origin_urls into v_product_id, v_origin_urls
    from public.products
    where client_id = p_product_id and client_secret = p_client_secret and status = true and deleted_at is null;
  end if;

  if v_product_id is null then
    return false;
  end if;

  -- Product must have at least one origin_url configured; otherwise validation fails
  if v_origin_urls is null or cardinality(v_origin_urls) = 0 then
    return false;
  end if;

  -- Get origin from request headers (set by API layer or db-pre-request hook)
  v_origin := public.get_request_origin();
  if v_origin is null or trim(v_origin) = '' then
    return false;
  end if;
  if not public.validate_product_origin(v_product_id, v_origin) then
    return false;
  end if;

  return true;
end;
$$;

comment on function public.validate_client_secret(text, text) is 'Validates client_id, client_secret and origin. Origin is read from request headers (get_request_origin). Product must have origin_urls configured.';

grant execute on function public.validate_client_secret(text, text) to authenticated, anon;

create or replace function public.get_product_by_client_secret(p_client_secret text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id uuid;
begin
  select id into v_product_id
  from public.products
  where client_secret = p_client_secret and status = true and deleted_at is null
  limit 1;
  return v_product_id;
end;
$$;

comment on function public.get_product_by_client_secret(text) is 'Returns the product_id for a valid client_secret. Returns null if invalid or product inactive/deleted.';

grant execute on function public.get_product_by_client_secret(text) to authenticated, anon;
