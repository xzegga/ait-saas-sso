# Product Origin URL Validation Setup

## Overview

This document explains how to set up automatic origin URL validation for products. This adds an additional layer of security by ensuring that requests to product endpoints can only come from the configured origin URL.

## Security Model

The validation system enforces the following security model:

- **Public endpoints (anon)**: Require **API key + origin validation**
- **Private endpoints (authenticated)**: Require **API key + origin validation + JWT**
- **Super admins**: Bypass origin validation (but still require API key and JWT)

**Important Notes:**
- The API key is always required and validated by Supabase before RLS policies are evaluated
- JWT is required for authenticated endpoints (validated by Supabase)
- Super admins bypass origin validation but must still be authenticated with valid JWT
- Origin validation only applies when `origin_url` is configured for a product

## How It Works

1. Each product can have an `origin_url` configured (e.g., `http://localhost:5174`, `https://app.example.com`)
2. When a request is made, the system validates that the `Origin` or `Referer` header matches the product's `origin_url`
3. If the origin doesn't match, the request is denied

## Database Schema

The `products` table now includes an `origin_url` column:

```sql
ALTER TABLE public.products
ADD COLUMN origin_url text;
```

## Configuration

### Step 1: Configure Origin URL for Products

Update your products to include the `origin_url`:

```sql
UPDATE public.products
SET origin_url = 'http://localhost:5174'
WHERE client_id = 'prod_example_app';
```

### Step 2: Set Up PostgREST Hook (Required for Automatic Validation)

To enable automatic origin validation, you need to configure a PostgREST hook that extracts the `Origin` or `Referer` header and sets it in the request context.

#### Option A: Using Supabase Edge Functions (Recommended)

Create a Supabase Edge Function that acts as middleware:

```typescript
// supabase/functions/validate-origin/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const origin = req.headers.get('origin') || req.headers.get('referer')
  
  // Extract just the origin part (protocol://domain:port)
  const originUrl = origin ? new URL(origin).origin : null
  
  // Set the origin in the request context
  // This will be available to PostgreSQL functions via current_setting('request.origin')
  // Note: This requires custom PostgREST configuration
  
  return new Response(JSON.stringify({ origin: originUrl }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

#### Option B: Using PostgREST Configuration

If you have access to PostgREST configuration, you can add a hook that sets the origin:

```haskell
-- In PostgREST configuration
-- This is a simplified example - actual implementation depends on your setup
db-pre-request = "SELECT set_config('request.origin', current_setting('request.headers.origin', true), true)"
```

**Note:** PostgREST doesn't natively expose HTTP headers to PostgreSQL. You'll need a custom solution or use Supabase Edge Functions.

### Step 3: Manual Validation (Alternative)

If automatic header extraction is not available, you can validate the origin manually in your application code:

```typescript
// In your frontend code
const origin = window.location.origin; // e.g., http://localhost:5174

// When making requests, include the origin in a custom header
const response = await supabase
  .from('products')
  .select('*')
  .eq('client_id', 'prod_example_app')
  .eq('origin', origin); // This would require a custom RPC function
```

## Functions Available

### `validate_product_origin(p_product_id uuid, p_origin text)`

Validates that a given origin matches the product's configured `origin_url`.

```sql
SELECT public.validate_product_origin(
  'product-uuid-here',
  'http://localhost:5174'
);
```

### `is_product_origin_valid(p_product_id uuid)`

Validates product origin using the origin from request context (requires `request.origin` to be set).

```sql
SELECT public.is_product_origin_valid('product-uuid-here');
```

### `is_product_origin_valid_by_client_id(p_client_id text, p_origin text)`

Validates product origin by client_id (slug) instead of UUID.

```sql
SELECT public.is_product_origin_valid_by_client_id(
  'prod_example_app',
  'http://localhost:5174'
);
```

## RLS Policies

The RLS policies have been updated to include origin validation:

- **products**: Validates origin when `origin_url` is configured
- **product_plans**: Validates origin through the related product
- **product_plan_prices**: Validates origin through the product_plan and product

All policies allow access if:
1. The product has no `origin_url` configured (backward compatibility)
2. The origin validation passes (when `request.origin` is set by a hook)

## Backward Compatibility

- Products without `origin_url` configured will continue to work (no validation)
- If `request.origin` is not available in the context, validation is skipped (allows access)
- This ensures existing functionality continues to work while new products can opt into origin validation

## Security Considerations

1. **Always configure `origin_url` for production products** - Don't rely on backward compatibility
2. **Use HTTPS in production** - Origin validation is more secure with HTTPS
3. **Be careful with localhost** - Only use `http://localhost` for development
4. **Consider port numbers** - Include port numbers in `origin_url` if your app uses non-standard ports

## Troubleshooting

### Origin validation not working

1. Check that `origin_url` is configured for your product
2. Verify that `request.origin` is being set by your hook/middleware
3. Check the browser console for CORS errors
4. Verify the origin format matches exactly (including protocol and port)

### Requests being denied

1. Check that the `Origin` or `Referer` header is being sent
2. Verify the `origin_url` matches exactly (case-insensitive, but protocol and port must match)
3. Check that the product exists and is not deleted

## Example Configuration

```sql
-- Configure origin for a product
UPDATE public.products
SET origin_url = 'https://app.example.com'
WHERE client_id = 'prod_my_app';

-- For development
UPDATE public.products
SET origin_url = 'http://localhost:5174'
WHERE client_id = 'prod_my_app_dev';
```
