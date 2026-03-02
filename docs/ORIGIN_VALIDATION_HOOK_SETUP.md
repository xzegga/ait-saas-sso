# Origin Validation Hook Setup

## Overview

This document explains how the origin validation hook works and how to configure it. The hook automatically extracts the origin from HTTP request headers and validates it against the product's configured `origin_url`.

## How It Works

1. **PostgREST Hook**: Before each request, PostgREST calls `extract_request_origin()` function
2. **Header Extraction**: The function extracts the origin from HTTP headers in this order:
   - `X-Request-Origin` (custom header, set by Edge Function or SDK)
   - `Origin` (standard HTTP header)
   - `Referer` (fallback, extracts origin from full URL)
3. **Storage**: The extracted origin is stored in `request.origin` session variable
4. **Validation**: RLS policies use `is_product_origin_valid()` which calls `get_request_origin()` to get the stored origin
5. **Comparison**: The origin is compared against `products.origin_url` field

## Configuration

### 1. Database Migration

The migration `20250101000032_origin_validation_hook.sql` creates:
- `extract_request_origin()`: Function to extract origin from headers
- Updated `get_request_origin()`: Function to retrieve stored origin

### 2. PostgREST Configuration

In `supabase/config.toml`, the hook is configured:

```toml
[api]
db-pre-request = "public.extract_request_origin"
```

This makes PostgREST call `extract_request_origin()` before each request.

### 3. Edge Function (Optional)

An Edge Function `_middleware-origin` is available to act as middleware:
- Extracts `Origin` or `Referer` header
- Sets `X-Request-Origin` header before forwarding to PostgREST
- This ensures the origin is always available even if browsers don't send `Origin` header

## Header Priority

The hook tries to extract origin from headers in this order:

1. **X-Request-Origin** (highest priority)
   - Set by Edge Function middleware
   - Can be set by SDK if needed
   - Format: `http://localhost:5174`

2. **Origin** (standard HTTP header)
   - Automatically sent by browsers for CORS requests
   - Format: `http://localhost:5174`

3. **Referer** (fallback)
   - Contains full URL of the page making the request
   - Origin is extracted from the URL
   - Format: `http://localhost:5174/some/path` → extracts `http://localhost:5174`

## Origin Normalization

The extracted origin is normalized:
- Converted to lowercase
- Trailing slashes removed
- Whitespace trimmed

Example:
- `http://localhost:5174/` → `http://localhost:5174`
- `HTTP://LOCALHOST:5174` → `http://localhost:5174`
- `http://localhost:5174/  ` → `http://localhost:5174`

## Validation Flow

```
1. Request arrives at Supabase
   ↓
2. PostgREST calls extract_request_origin()
   ↓
3. Function extracts origin from headers
   ↓
4. Origin stored in request.origin session variable
   ↓
5. RLS policy calls is_product_origin_valid(product_id)
   ↓
6. get_request_origin() retrieves stored origin
   ↓
7. validate_product_origin() compares with products.origin_url
   ↓
8. Access granted or denied based on match
```

## Testing

### Test with curl

```bash
# Test with Origin header
curl -X GET "http://127.0.0.1:54321/rest/v1/products" \
  -H "Origin: http://localhost:5174" \
  -H "apikey: YOUR_API_KEY"

# Test with X-Request-Origin header
curl -X GET "http://127.0.0.1:54321/rest/v1/products" \
  -H "X-Request-Origin: http://localhost:5174" \
  -H "apikey: YOUR_API_KEY"
```

### Verify Origin Extraction

You can verify that the origin is being extracted by checking the session variable:

```sql
-- This will show the current request.origin value
SELECT current_setting('request.origin', true);
```

## Troubleshooting

### Origin not being extracted

1. **Check PostgREST configuration**: Ensure `db-pre-request` is set in `config.toml`
2. **Check headers**: Verify that `Origin`, `Referer`, or `X-Request-Origin` header is being sent
3. **Check function**: Verify `extract_request_origin()` function exists and has correct permissions
4. **Check logs**: Look for errors in PostgREST logs

### Validation not working

1. **Check product configuration**: Ensure `origin_url` is set for the product
2. **Check origin format**: Verify origin matches exactly (case-insensitive, but protocol and port must match)
3. **Check super admin**: Super admins bypass validation - verify user role
4. **Check backward compatibility**: If `origin_url` is NULL, validation is skipped

### Headers not available

PostgREST may not expose all headers in all scenarios. If headers are not available:
- Use Edge Function middleware to set `X-Request-Origin` header
- Or manually pass origin in custom header from SDK

## Security Considerations

1. **Always configure `origin_url` for production products** - Don't rely on backward compatibility
2. **Use HTTPS in production** - Origin validation is more secure with HTTPS
3. **Be careful with localhost** - Only use `http://localhost` for development
4. **Include port numbers** - If your app uses non-standard ports, include them in `origin_url`
5. **Validate exact match** - The validation is case-insensitive but protocol and port must match exactly

## Backward Compatibility

The system maintains backward compatibility:
- Products without `origin_url` configured will continue to work (no validation)
- If origin cannot be extracted, validation is skipped (allows access)
- This ensures existing functionality continues to work while new products can opt into origin validation

## Production Deployment

For production:
1. Ensure `db-pre-request` hook is configured in Supabase project settings
2. Configure `origin_url` for all products
3. Use HTTPS for all origins
4. Monitor logs for validation failures
5. Consider using Edge Function middleware for more control
