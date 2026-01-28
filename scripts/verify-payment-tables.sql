-- Script to verify payment tables exist
-- Run this in Supabase SQL Editor

-- Check if payment_providers table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_providers'
    ) 
    THEN '✅ payment_providers EXISTS' 
    ELSE '❌ payment_providers DOES NOT EXIST' 
  END as payment_providers_status;

-- Check if payment_accounts table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_accounts'
    ) 
    THEN '✅ payment_accounts EXISTS' 
    ELSE '❌ payment_accounts DOES NOT EXIST' 
  END as payment_accounts_status;

-- Check if payment_products table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_products'
    ) 
    THEN '✅ payment_products EXISTS' 
    ELSE '❌ payment_products DOES NOT EXIST' 
  END as payment_products_status;

-- Check if payment_prices table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_prices'
    ) 
    THEN '✅ payment_prices EXISTS' 
    ELSE '❌ payment_prices DOES NOT EXIST' 
  END as payment_prices_status;

-- Check if payment_subscriptions table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_subscriptions'
    ) 
    THEN '✅ payment_subscriptions EXISTS' 
    ELSE '❌ payment_subscriptions DOES NOT EXIST' 
  END as payment_subscriptions_status;

-- Check if payment_invoices table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_invoices'
    ) 
    THEN '✅ payment_invoices EXISTS' 
    ELSE '❌ payment_invoices DOES NOT EXIST' 
  END as payment_invoices_status;

-- Check if payment_webhook_events table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name = 'payment_webhook_events'
    ) 
    THEN '✅ payment_webhook_events EXISTS' 
    ELSE '❌ payment_webhook_events DOES NOT EXIST' 
  END as payment_webhook_events_status;

-- List all applied migrations
SELECT 
  version,
  name,
  inserted_at
FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 10;

-- List all payment-related tables
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'payment%'
ORDER BY table_name;
