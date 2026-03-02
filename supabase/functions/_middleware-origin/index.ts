/**
 * Origin Validation Middleware
 * 
 * This Edge Function acts as middleware to extract the Origin/Referer header
 * and set it in the request context before forwarding to PostgREST.
 * 
 * IMPORTANT: This is a private function (prefixed with _) and should be
 * called internally by Supabase, not directly by clients.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Extract origin from request headers
    const origin = req.headers.get('origin') || req.headers.get('referer')
    
    // Parse origin to get just the protocol://domain:port part
    let originUrl: string | null = null
    if (origin) {
      try {
        const url = new URL(origin)
        originUrl = `${url.protocol}//${url.host}`
      } catch {
        // If URL parsing fails, use origin as-is (might be just domain)
        originUrl = origin
      }
    }
    
    // Normalize origin: lowercase, remove trailing slashes
    if (originUrl) {
      originUrl = originUrl.toLowerCase().replace(/\/+$/, '')
    }
    
    // Get the original request path and method
    const url = new URL(req.url)
    const path = url.pathname
    const method = req.method
    
    // Forward the request to PostgREST with origin in context
    // Note: We need to set the origin in a way that PostgreSQL can access it
    // Since we can't directly set PostgreSQL session variables from Edge Functions,
    // we'll pass it as a custom header that PostgREST can use
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:54321'
    const postgrestUrl = `${supabaseUrl}/rest/v1${path}${url.search}`
    
    // Forward request to PostgREST with origin in custom header
    const forwardHeaders = new Headers(req.headers)
    if (originUrl) {
      forwardHeaders.set('X-Request-Origin', originUrl)
    }
    
    // Forward the request
    const response = await fetch(postgrestUrl, {
      method: method,
      headers: forwardHeaders,
      body: req.body,
    })
    
    // Return the response
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers,
    })
  } catch (error) {
    console.error('Error in origin middleware:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})
