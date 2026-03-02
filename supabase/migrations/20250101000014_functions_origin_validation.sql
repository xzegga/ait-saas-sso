-- ==============================================================================
-- 014 - ORIGIN VALIDATION FUNCTIONS (products.origin_urls in 001)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.validate_product_origin(p_product_id uuid, p_origin text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_origin_urls text[];
  v_normalized_origin text;
  v_allowed text;
BEGIN
  SELECT origin_urls INTO v_origin_urls
  FROM public.products
  WHERE id = p_product_id AND deleted_at IS NULL;

  -- No origins configured: no origin check (allow)
  IF v_origin_urls IS NULL OR cardinality(v_origin_urls) = 0 THEN
    RETURN true;
  END IF;

  v_normalized_origin := lower(trim(both '/' from trim(coalesce(p_origin, ''))));
  IF v_normalized_origin = '' THEN
    RETURN false;
  END IF;

  -- Check if request origin matches any allowed origin
  FOREACH v_allowed IN ARRAY v_origin_urls
  LOOP
    IF lower(trim(both '/' from trim(coalesce(v_allowed, '')))) = v_normalized_origin THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.validate_product_origin IS 'Validates that the provided origin is in the product origin_urls array. If product has no origin_urls, returns true (no restriction).';

-- extract_request_origin: for PostgREST db-pre-request hook (from original 032)
CREATE OR REPLACE FUNCTION public.extract_request_origin()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_origin text;
  v_referer text;
  v_custom_origin text;
BEGIN
  BEGIN
    v_custom_origin := current_setting('request.headers.x-request-origin', true);
    IF v_custom_origin IS NOT NULL AND v_custom_origin != '' THEN
      v_origin := v_custom_origin;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  IF v_origin IS NULL THEN
    BEGIN
      v_origin := current_setting('request.headers.origin', true);
    EXCEPTION WHEN OTHERS THEN v_origin := NULL;
    END;
  END IF;

  IF v_origin IS NULL THEN
    BEGIN
      v_referer := current_setting('request.headers.referer', true);
      IF v_referer IS NOT NULL AND v_referer != '' THEN
        v_origin := regexp_replace(regexp_replace(v_referer, '^([^/]+://[^/]+).*$', '\1'), '/$', '');
        IF v_origin = v_referer THEN
          v_origin := regexp_replace(v_referer, '^(https?://[^/]+).*$', '\1');
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN v_origin := NULL;
    END;
  END IF;

  IF v_origin IS NOT NULL AND v_origin != '' THEN
    v_origin := lower(trim(both '/' from trim(v_origin)));
    PERFORM set_config('request.origin', v_origin, false);
  END IF;
END;
$$;

COMMENT ON FUNCTION public.extract_request_origin IS 'Extracts origin from request headers and stores it in request.origin. Call from PostgREST db-pre-request hook.';

-- get_request_origin: robust version with header fallbacks (from original 032)
CREATE OR REPLACE FUNCTION public.get_request_origin()
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_origin text;
BEGIN
  BEGIN
    v_origin := current_setting('request.origin', true);
    IF v_origin IS NOT NULL AND v_origin != '' THEN
      RETURN v_origin;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    v_origin := current_setting('request.headers.x-request-origin', true);
    IF v_origin IS NOT NULL AND v_origin != '' THEN
      v_origin := lower(trim(both '/' from trim(v_origin)));
      PERFORM set_config('request.origin', v_origin, false);
      RETURN v_origin;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    v_origin := current_setting('request.headers.origin', true);
    IF v_origin IS NOT NULL AND v_origin != '' THEN
      v_origin := lower(trim(both '/' from trim(v_origin)));
      PERFORM set_config('request.origin', v_origin, false);
      RETURN v_origin;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- PostgREST may expose headers as JSON: request.headers->>'origin'
  BEGIN
    v_origin := (current_setting('request.headers', true)::json)->>'origin';
    IF v_origin IS NOT NULL AND v_origin != '' THEN
      v_origin := lower(trim(both '/' from trim(v_origin)));
      PERFORM set_config('request.origin', v_origin, false);
      RETURN v_origin;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    v_origin := current_setting('request.headers.referer', true);
    IF v_origin IS NULL OR v_origin = '' THEN
      v_origin := (current_setting('request.headers', true)::json)->>'referer';
    END IF;
    IF v_origin IS NOT NULL AND v_origin != '' THEN
      v_origin := regexp_replace(regexp_replace(v_origin, '^([^/]+://[^/]+).*$', '\1'), '/$', '');
      IF v_origin IS NOT NULL AND v_origin != '' THEN
        v_origin := lower(trim(both '/' from trim(v_origin)));
        PERFORM set_config('request.origin', v_origin, false);
        RETURN v_origin;
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.get_request_origin IS 'Gets origin from request context or extracts from headers (X-Request-Origin, Origin, Referer).';

CREATE OR REPLACE FUNCTION public.is_product_origin_valid(p_product_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_origin text;
BEGIN
  IF (select public.is_super_admin()) THEN
    RETURN true;
  END IF;

  v_origin := public.get_request_origin();

  IF v_origin IS NULL THEN
    RETURN true;
  END IF;

  RETURN public.validate_product_origin(p_product_id, v_origin);
END;
$$;

COMMENT ON FUNCTION public.is_product_origin_valid IS 'Validates product origin from request context. Super admins bypass.';

CREATE OR REPLACE FUNCTION public.is_product_origin_valid_by_client_id(p_client_id text, p_origin text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_product_id uuid;
BEGIN
  SELECT id INTO v_product_id
  FROM public.products
  WHERE client_id = p_client_id AND deleted_at IS NULL;

  IF v_product_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN public.validate_product_origin(v_product_id, p_origin);
END;
$$;

COMMENT ON FUNCTION public.is_product_origin_valid_by_client_id IS 'Validates product origin by client_id.';

GRANT EXECUTE ON FUNCTION public.validate_product_origin(uuid, text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.extract_request_origin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_request_origin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_product_origin_valid(uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_product_origin_valid_by_client_id(text, text) TO authenticated, anon;
