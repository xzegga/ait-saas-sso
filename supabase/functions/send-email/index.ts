/**
 * Send Email Edge Function
 * 
 * This function sends emails using:
 * - Mailpit API in local development (for testing)
 * - Resend API in production
 * 
 * Security: Validates origin and client_secret (no JWT required)
 * 
 * IMPORTANT: This function should be invoked with --no-verify-jwt in development
 * or configured to skip JWT verification in production.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const RESEND_API_URL = 'https://api.resend.com/emails'

// Supabase configuration
// In Edge Functions, these are automatically available
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 
                     Deno.env.get('SUPABASE_SERVICE_URL') || 
                     Deno.env.get('SUPABASE_PROJECT_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 
                                   Deno.env.get('SUPABASE_SERVICE_KEY') || ''

// Detect if we're in local development
// Check multiple ways since SUPABASE_URL might not be set in Edge Functions
function detectLocalEnvironment(): boolean {
  const url = SUPABASE_URL.toLowerCase()
  const denoEnv = Deno.env.get('DENO_ENV')
  
  // Check if URL contains local indicators
  if (url.includes('127.0.0.1') || url.includes('localhost') || url.includes('0.0.0.0')) {
    return true
  }
  
  // Check if URL is empty (not set)
  if (!SUPABASE_URL || SUPABASE_URL === '') {
    return true
  }
  
  // Check DENO_ENV
  if (denoEnv === 'development') {
    return true
  }
  
  // If URL doesn't start with https://, likely local
  if (SUPABASE_URL && !SUPABASE_URL.startsWith('https://')) {
    return true
  }
  
  return false
}

const IS_LOCAL = detectLocalEnvironment()

// Log environment detection for debugging
console.log('Environment detection:', {
  SUPABASE_URL: SUPABASE_URL ? `${SUPABASE_URL.substring(0, 30)}...` : 'not set',
  DENO_ENV: Deno.env.get('DENO_ENV'),
  IS_LOCAL,
})

// Mailpit configuration (for local development)
// Mailpit accepts emails via SMTP on port 1025 (internal) / 54325 (host-mapped)
// From Edge Functions (Docker containers), we use the service name 'inbucket' and internal SMTP port 1025
const MAILPIT_SMTP_HOST = Deno.env.get('MAILPIT_SMTP_HOST') || 'inbucket'
const MAILPIT_SMTP_PORT = parseInt(Deno.env.get('MAILPIT_SMTP_PORT') || '1025')

interface EmailRequest {
  to: string | string[];
  subject: string;
  html: string;
  text?: string;
  from?: string;
  from_name?: string;
  client_secret?: string; // Product client_secret for validation
  origin?: string; // Request origin for validation
}

/**
 * Validate origin and client_secret
 */
async function validateRequest(
  clientSecret: string | undefined,
  origin: string | undefined,
  isLocal: boolean = IS_LOCAL
): Promise<{ valid: boolean; error?: string; productId?: string }> {
  // In local development, skip validation if no credentials provided
  if (isLocal && !clientSecret) {
    console.log('Local development: Skipping validation (no client_secret provided)')
    return { valid: true }
  }

  // In production or if clientSecret is provided, validate it
  if (!clientSecret) {
    return { valid: false, error: 'client_secret is required' }
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Supabase configuration missing:', {
      hasUrl: !!SUPABASE_URL,
      hasServiceKey: !!SUPABASE_SERVICE_ROLE_KEY,
    })
    return { valid: false, error: 'Supabase configuration missing' }
  }

  try {
    // Create Supabase client with service role key for validation
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Get product_id from client_secret
    const { data: productId, error: productError } = await supabase.rpc(
      'get_product_by_client_secret',
      { p_client_secret: clientSecret }
    )

    if (productError) {
      console.error('Error getting product by client_secret:', productError)
      return { valid: false, error: 'Invalid client_secret' }
    }

    if (!productId) {
      console.error('No product found for client_secret')
      return { valid: false, error: 'Invalid client_secret' }
    }

    // Validate origin if provided
    // In local development, be more lenient with origin validation
    if (origin) {
      const { data: originValid, error: originError } = await supabase.rpc(
        'is_product_origin_valid_by_client_id',
        {
          p_client_id: clientSecret,
          p_origin: origin,
        }
      )

      if (originError) {
        console.error('Origin validation error:', originError)
        // In local development, don't fail if origin validation has an error
        if (isLocal) {
          console.log('Local development: Allowing request despite origin validation error')
          // Continue with validation
        } else {
          // In production, log but don't fail (backward compatibility)
        }
      } else if (originValid === false) {
        // In local development, be more lenient
        if (isLocal) {
          console.warn('Local development: Origin validation failed, but allowing request', { origin, clientSecret })
          // Allow the request in local development even if origin doesn't match
          // This helps with testing when origin_urls is not configured
        } else {
          console.error('Origin validation failed:', { origin, clientSecret })
          return { valid: false, error: 'Invalid origin' }
        }
      }
    }

    return { valid: true, productId }
  } catch (error) {
    console.error('Validation error:', error)
    return { valid: false, error: 'Validation failed' }
  }
}

/**
 * Send email via Mailpit SMTP (for local development)
 * Uses SMTP protocol as Mailpit accepts emails via SMTP on port 1025
 */
async function sendViaMailpit(emailData: EmailRequest): Promise<Response> {
  const recipients = Array.isArray(emailData.to) ? emailData.to : [emailData.to]
  const fromEmail = emailData.from || 'ait-sso@ait-sso.com'
  const fromName = emailData.from_name || 'ait-sso'
  const subject = emailData.subject
  const html = emailData.html
  const text = emailData.text || emailData.html.replace(/<[^>]*>/g, '') // Strip HTML if no text version

  // Log without exposing recipient emails
  console.log(`[Mailpit] Sending email via SMTP to ${recipients.length} recipient(s)`)
  console.log(`[Mailpit] Using SMTP: ${MAILPIT_SMTP_HOST}:${MAILPIT_SMTP_PORT}`)
  
  try {
    // Connect to SMTP server
    const conn = await Deno.connect({
      hostname: MAILPIT_SMTP_HOST,
      port: MAILPIT_SMTP_PORT,
    })

    const encoder = new TextEncoder()
    const decoder = new TextDecoder()
    
    // Helper function to read SMTP response
    const readResponse = async (): Promise<string> => {
      const buffer = new Uint8Array(1024)
      const n = await conn.read(buffer)
      if (n === null) throw new Error('Connection closed')
      return decoder.decode(buffer.subarray(0, n))
    }

    // Helper function to send SMTP command
    const sendCommand = async (command: string): Promise<string> => {
      await conn.write(encoder.encode(command + '\r\n'))
      return await readResponse()
    }

    // SMTP conversation
    await readResponse() // Read initial greeting
    
    await sendCommand(`HELO ${MAILPIT_SMTP_HOST}`)
    await sendCommand(`MAIL FROM:<${fromEmail}>`)
    
    for (const recipient of recipients) {
      await sendCommand(`RCPT TO:<${recipient}>`)
    }
    
    await sendCommand('DATA')
    
    // Build email message in RFC 5322 format
    const message = [
      `From: ${fromName} <${fromEmail}>`,
      `To: ${recipients.map(r => `<${r}>`).join(', ')}`,
      `Subject: ${subject}`,
      `Content-Type: multipart/alternative; boundary="----=_Part_0_${Date.now()}"`,
      '',
      '------=_Part_0_' + Date.now(),
      'Content-Type: text/plain; charset="utf-8"',
      'Content-Transfer-Encoding: 7bit',
      '',
      text,
      '',
      '------=_Part_0_' + Date.now(),
      'Content-Type: text/html; charset="utf-8"',
      'Content-Transfer-Encoding: 7bit',
      '',
      html,
      '',
      '------=_Part_0_' + Date.now() + '--',
      '.',
    ].join('\r\n')
    
    await sendCommand(message)
    await sendCommand('QUIT')
    
    conn.close()
    
    console.log('[Mailpit] Email sent successfully via SMTP:', {
      to: recipients,
    })

    return new Response(
      JSON.stringify({ 
        success: true,
        messageId: `smtp-${Date.now()}`,
        to: emailData.to,
        via: 'mailpit-smtp'
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error)
    console.error('[Mailpit] Failed to send email via SMTP:', errorMsg)
    throw new Error(`Failed to send email via Mailpit SMTP: ${errorMsg}. Please ensure Mailpit is running and accessible at ${MAILPIT_SMTP_HOST}:${MAILPIT_SMTP_PORT}`)
  }
}

/**
 * Send email via Resend API (for production)
 */
async function sendViaResend(emailData: EmailRequest): Promise<Response> {
  if (!RESEND_API_KEY) {
    throw new Error('RESEND_API_KEY is not configured')
  }

  const resendPayload: any = {
    from: emailData.from || 'ait-sso@ait-sso.com',
    to: Array.isArray(emailData.to) ? emailData.to : [emailData.to],
    subject: emailData.subject,
    html: emailData.html,
  }

  // Add text version if provided
  if (emailData.text) {
    resendPayload.text = emailData.text
  }

  // Add from name if provided
  if (emailData.from_name) {
    resendPayload.from = `${emailData.from_name} <${resendPayload.from}>`
  }

  const resendResponse = await fetch(RESEND_API_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(resendPayload),
  })

  const resendData = await resendResponse.json()

  if (!resendResponse.ok) {
    console.error('Resend API error:', resendData)
    throw new Error(`Resend API error: ${JSON.stringify(resendData)}`)
  }

  // Log without exposing recipient emails
  const recipientCount = Array.isArray(emailData.to) ? emailData.to.length : 1
  console.log('Email sent via Resend:', {
    messageId: resendData.id,
    recipientCount,
  })

  return new Response(
    JSON.stringify({ 
      success: true,
      messageId: resendData.id,
      to: emailData.to,
      via: 'resend'
    }),
    { 
      status: 200,
      headers: { 'Content-Type': 'application/json' } 
    }
  )
}

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Check for authorization header (required for security)
    // In local development, be more lenient for testing
    const authHeader = req.headers.get('Authorization')
    const isLocalRequest = detectLocalEnvironment()
    
    if (!authHeader) {
      if (isLocalRequest) {
        console.warn('[Local Dev] Missing authorization header, but allowing request for testing')
      } else {
        console.error('Missing authorization header')
        return new Response(
          JSON.stringify({ error: 'Missing authorization header' }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        )
      }
    } else if (!authHeader.startsWith('Bearer ')) {
      if (isLocalRequest) {
        console.warn('[Local Dev] Invalid authorization header format, but allowing request for testing')
      } else {
        console.error('Invalid authorization header format')
        return new Response(
          JSON.stringify({ error: 'Invalid authorization header format' }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        )
      }
    }

    // Parse request body
    let emailData: EmailRequest
    try {
      emailData = await req.json()
    } catch (error) {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON in request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Validate required fields
    if (!emailData.to || !emailData.subject || !emailData.html) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: to, subject, html' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Extract origin from request headers if not provided in body
    const requestOrigin = emailData.origin || 
                         req.headers.get('origin') || 
                         req.headers.get('referer') || 
                         undefined

    // Normalize origin (extract just protocol://host:port)
    let normalizedOrigin: string | undefined = undefined
    if (requestOrigin) {
      try {
        const url = new URL(requestOrigin)
        normalizedOrigin = `${url.protocol}//${url.host}`
      } catch {
        normalizedOrigin = requestOrigin
      }
    }

    // Re-detect local environment on each request (in case env vars change)
    // Note: isLocalRequest was already detected above for auth check
    
    // Log request without exposing sensitive data
    const recipients = Array.isArray(emailData.to) ? emailData.to : [emailData.to]
    console.log('Email request received:', {
      recipientCount: recipients.length,
      recipientDomains: recipients.map((email: string) => email.split('@')[1] || 'unknown'), // Only log domain, not full email
      hasClientSecret: !!emailData.client_secret,
      origin: normalizedOrigin,
      isLocal: isLocalRequest,
      hasSubject: !!emailData.subject,
      hasHtml: !!emailData.html,
    })

    // Validate request (origin and client_secret)
    // Pass isLocalRequest to validation function
    const validation = await validateRequest(
      emailData.client_secret,
      normalizedOrigin,
      isLocalRequest
    )

    if (!validation.valid) {
      console.error('Validation failed:', {
        error: validation.error,
        hasClientSecret: !!emailData.client_secret,
        origin: normalizedOrigin,
        // Don't log client_secret or recipient emails
      })
      return new Response(
        JSON.stringify({ 
          error: 'Validation failed',
          message: validation.error || 'Invalid request'
        }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log('Validation passed, sending email via', isLocalRequest ? 'Mailpit' : 'Resend')

    // Use Mailpit in local development, Resend in production
    if (isLocalRequest) {
      return await sendViaMailpit(emailData)
    } else {
      
      // In production, require RESEND_API_KEY
      if (!RESEND_API_KEY) {
        return new Response(
          JSON.stringify({ 
            error: 'Email service not configured',
            message: 'RESEND_API_KEY is required in production'
          }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        )
      }
      
      return await sendViaResend(emailData)
    }
  } catch (error) {
    console.error('Error in send-email function:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  }
})
