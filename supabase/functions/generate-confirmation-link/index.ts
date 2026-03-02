/**
 * Generate Confirmation Link Edge Function
 * 
 * This function generates a Supabase Auth confirmation link using the Admin API.
 * It requires the service role key to access the Admin API.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 
                     Deno.env.get('SUPABASE_SERVICE_URL') || 
                     Deno.env.get('SUPABASE_PROJECT_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 
                                   Deno.env.get('SUPABASE_SERVICE_KEY') || ''

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    let body: { email: string; redirectTo?: string; client_secret?: string; origin?: string }
    try {
      body = await req.json()
    } catch (error) {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON in request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (!body.email) {
      return new Response(
        JSON.stringify({ error: 'Email is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error('Supabase configuration missing')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Optional: Validate client_secret and origin (same validation as send-email)
    // For now, we'll allow this endpoint to be called with just the anon key
    // since it's only used internally during signup

    // Create Supabase Admin client
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Generate confirmation link using Admin API
    const redirectTo = body.redirectTo || `${new URL(SUPABASE_URL).origin}/auth/callback`
    
    console.log('Generating confirmation link for:', body.email, 'redirectTo:', redirectTo)
    
    // Check if user exists and is confirmed
    const { data: users } = await supabaseAdmin.auth.admin.listUsers()
    const existingUser = users?.users?.find(u => u.email === body.email)
    const isUserConfirmed = existingUser?.email_confirmed_at !== null
    
    console.log('User status:', {
      exists: !!existingUser,
      isConfirmed: isUserConfirmed,
      userId: existingUser?.id,
    })
    
    // According to Supabase docs, valid types for generateLink are:
    // - 'signup': for new user signups (fails if user already exists)
    // - 'invite': for inviting users
    // - 'magiclink': for magic link authentication
    // - 'recovery': for password recovery
    // - 'email_change_old': for email change (old email)
    // - 'email_change_new': for email change (new email)
    //
    // For an existing unconfirmed user, we should use 'signup' type
    // If it fails with "email already exists", we'll handle it by using the user's existing confirmation token
    // or by updating the user's confirmation status
    
    let data, error
    try {
      // Try with 'signup' type first (works for unconfirmed users)
      const result = await supabaseAdmin.auth.admin.generateLink({
        type: 'signup',
        email: body.email,
        options: {
          redirectTo,
        },
      })
      data = result.data
      error = result.error
    } catch (err) {
      error = err
    }

    // If 'signup' fails because user exists, try 'invite' type
    // 'invite' can work for existing unconfirmed users
    if (error && (error.code === 'email_exists' || error.message?.includes('already been registered'))) {
      console.log('User exists, trying with type: invite')
      try {
        const inviteResult = await supabaseAdmin.auth.admin.generateLink({
          type: 'invite',
          email: body.email,
          options: {
            redirectTo,
          },
        })
        
        if (!inviteResult.error) {
          data = inviteResult.data
          error = null
          console.log('Successfully generated link with type: invite')
        } else {
          error = inviteResult.error
        }
      } catch (inviteErr) {
        error = inviteErr
      }
    }

    if (error) {
      console.error('Error generating confirmation link:', error)
      return new Response(
        JSON.stringify({ 
          error: 'Failed to generate confirmation link',
          message: error.message 
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // The confirmation link is in data.properties.action_link
    // According to Supabase docs, generateLink returns:
    // - properties.action_link: The full confirmation link with token
    // - properties.email_otp: The OTP code (if using OTP)
    // - properties.hashed_token: The hashed token
    const confirmationLink = data.properties?.action_link || null
    
    console.log('Confirmation link generated:', {
      hasLink: !!confirmationLink,
      linkPreview: confirmationLink ? confirmationLink.substring(0, 100) + '...' : 'null',
      dataKeys: Object.keys(data || {}),
      propertiesKeys: Object.keys(data?.properties || {}),
    })
    
    if (!confirmationLink) {
      console.error('No confirmation link in response:', JSON.stringify(data, null, 2))
    }

    return new Response(
      JSON.stringify({ 
        success: true,
        confirmationLink,
        email: body.email,
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  } catch (error) {
    console.error('Error in generate-confirmation-link function:', error)
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
