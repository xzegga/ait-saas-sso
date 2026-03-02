/**
 * Register Confirmation Sent Edge Function
 * 
 * This function updates the confirmation_sent_at field in auth.users
 * without confirming the user. It uses the Admin API to update the user record.
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
    let body: { email: string }
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

    // Create Supabase Admin client
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    console.log('Registering confirmation_sent_at for:', body.email)

    // Get user by email using Admin API
    const { data: users, error: listError } = await supabaseAdmin.auth.admin.listUsers()
    
    if (listError) {
      console.error('Error listing users:', listError)
      return new Response(
        JSON.stringify({ 
          error: 'Failed to find user',
          message: listError.message 
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const user = users.users.find(u => u.email === body.email)
    
    if (!user) {
      return new Response(
        JSON.stringify({ 
          error: 'User not found',
          message: `No user found with email: ${body.email}`
        }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Check if user is already confirmed
    // In local dev with SMTP disabled, Supabase may auto-confirm users
    const wasConfirmed = user.email_confirmed_at !== null
    
    console.log('User confirmation status before update:', {
      email: body.email,
      userId: user.id,
      wasConfirmed,
      confirmedAt: user.email_confirmed_at,
      confirmationSentAt: user.confirmation_sent_at,
    })

    // If user is already confirmed but shouldn't be (they haven't clicked the link),
    // unconfirm them first
    if (wasConfirmed) {
      console.log('User is already confirmed, unconfirming so they must click the link...')
      const { error: unconfirmError } = await supabaseAdmin.auth.admin.updateUserById(
        user.id,
        {
          email_confirm: false,
        }
      )

      if (unconfirmError) {
        console.error('Error unconfirming user:', unconfirmError)
        // Continue anyway - we'll try to update confirmation_sent_at
      } else {
        console.log('User unconfirmed successfully')
      }
    }

    // Use database function to update confirmation_sent_at directly
    // This avoids auto-confirmation that might happen with generateLink
    const { data: dbResult, error: dbError } = await supabaseAdmin.rpc(
      'update_confirmation_sent_at',
      { p_user_id: user.id }
    )

    if (dbError) {
      console.error('Error updating confirmation_sent_at via RPC:', dbError)
      // Fallback: use generateLink (but this may auto-confirm in local dev)
      console.log('Falling back to generateLink method...')
      const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
        type: 'signup',
        email: body.email,
      })

      if (linkError) {
        return new Response(
          JSON.stringify({ 
            error: 'Failed to register confirmation sent',
            message: linkError.message 
          }),
          { status: 500, headers: { 'Content-Type': 'application/json' } }
        )
      }

      // Check if user was auto-confirmed by generateLink
      const { data: updatedUsers } = await supabaseAdmin.auth.admin.listUsers()
      const updatedUser = updatedUsers?.users.find(u => u.id === user.id)
      
      if (updatedUser && updatedUser.email_confirmed_at) {
        console.log('User was auto-confirmed by generateLink, unconfirming...')
        await supabaseAdmin.auth.admin.updateUserById(user.id, {
          email_confirm: false,
        })
      }
    } else {
      console.log('Confirmation sent timestamp updated via RPC function')
    }

    return new Response(
      JSON.stringify({ 
        success: true,
        message: 'Confirmation sent timestamp registered',
        userId: user.id,
        email: body.email,
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  } catch (error) {
    console.error('Error in register-confirmation-sent function:', error)
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
