/**
 * Supabase configuration for localhost
 */

// Supabase localhost configuration
// These values match your local Supabase instance
// You can override them via .env.local file
export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'http://127.0.0.1:54321';
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || '';

// Product configuration
// Get these values from the IDP admin panel after creating your product
export const PRODUCT_ID = import.meta.env.VITE_PRODUCT_ID || '';
export const CLIENT_SECRET = import.meta.env.VITE_CLIENT_SECRET || '';
