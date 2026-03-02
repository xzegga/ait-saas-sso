-- ==============================================================================
-- PAYMENT SYNC FUNCTIONS - Generic Payment System
-- ==============================================================================
-- Generic functions to sync data between our system and payment providers
-- ==============================================================================

-- Function: Create or update payment account for an organization
create or replace function public.sync_payment_account(
  p_org_id uuid,
  p_provider_id uuid,
  p_external_account_id text,
  p_email text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account_id uuid;
begin
  -- Check if account already exists
  select id into v_account_id
  from public.payment_accounts
  where (org_id = p_org_id and provider_id = p_provider_id)
     or (provider_id = p_provider_id and external_account_id = p_external_account_id);

  if v_account_id is not null then
    -- Update existing account
    update public.payment_accounts
    set 
      external_account_id = p_external_account_id,
      email = coalesce(p_email, email),
      metadata = p_metadata,
      updated_at = now()
    where id = v_account_id;
  else
    -- Insert new account
    insert into public.payment_accounts (org_id, provider_id, external_account_id, email, metadata)
    values (p_org_id, p_provider_id, p_external_account_id, p_email, p_metadata)
    returning id into v_account_id;
  end if;

  return v_account_id;
end;
$$;

comment on function public.sync_payment_account is 'Create or update payment account for an organization';

-- Function: Create or update payment product mapping
create or replace function public.sync_payment_product(
  p_product_id uuid,
  p_provider_id uuid,
  p_external_product_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_product_id uuid;
begin
  -- Check if product mapping already exists
  select id into v_payment_product_id
  from public.payment_products
  where (product_id = p_product_id and provider_id = p_provider_id)
     or (provider_id = p_provider_id and external_product_id = p_external_product_id);

  if v_payment_product_id is not null then
    -- Update existing mapping
    update public.payment_products
    set 
      external_product_id = p_external_product_id,
      metadata = p_metadata,
      updated_at = now()
    where id = v_payment_product_id;
  else
    -- Insert new mapping
    insert into public.payment_products (product_id, provider_id, external_product_id, metadata)
    values (p_product_id, p_provider_id, p_external_product_id, p_metadata)
    returning id into v_payment_product_id;
  end if;

  return v_payment_product_id;
end;
$$;

comment on function public.sync_payment_product is 'Create or update payment product mapping';

-- Function: Create or update payment price mapping
create or replace function public.sync_payment_price(
  p_product_plan_id uuid,
  p_provider_id uuid,
  p_external_price_id text,
  p_external_product_id text,
  p_billing_interval text default 'month',
  p_currency text default 'usd',
  p_amount bigint default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_price_id uuid;
begin
  -- Check if price mapping already exists
  select id into v_payment_price_id
  from public.payment_prices
  where (product_plan_id = p_product_plan_id and provider_id = p_provider_id)
     or (provider_id = p_provider_id and external_price_id = p_external_price_id);

  if v_payment_price_id is not null then
    -- Update existing mapping
    update public.payment_prices
    set 
      external_price_id = p_external_price_id,
      external_product_id = p_external_product_id,
      billing_interval = p_billing_interval,
      currency = p_currency,
      amount = p_amount,
      metadata = p_metadata,
      updated_at = now()
    where id = v_payment_price_id;
  else
    -- Insert new mapping
    insert into public.payment_prices (
      product_plan_id,
      provider_id,
      external_price_id,
      external_product_id,
      billing_interval,
      currency,
      amount,
      metadata
    )
    values (
      p_product_plan_id,
      p_provider_id,
      p_external_price_id,
      p_external_product_id,
      p_billing_interval,
      p_currency,
      p_amount,
      p_metadata
    )
    returning id into v_payment_price_id;
  end if;

  return v_payment_price_id;
end;
$$;

comment on function public.sync_payment_price is 'Create or update payment price mapping';

-- Function: Sync subscription status from payment provider webhook
create or replace function public.sync_payment_subscription(
  p_subscription_id uuid,
  p_provider_id uuid,
  p_payment_account_id uuid,
  p_external_subscription_id text,
  p_external_price_id text,
  p_status text,
  p_provider_status text,
  p_current_period_start timestamptz default null,
  p_current_period_end timestamptz default null,
  p_cancel_at_period_end boolean default false,
  p_canceled_at timestamptz default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_subscription_id uuid;
  v_internal_status text;
begin
  -- Map provider status to our internal normalized status
  -- This allows different providers to use different status names
  case lower(p_status)
    when 'active', 'trialing' then
      v_internal_status := 'active';
    when 'past_due', 'unpaid', 'payment_failed' then
      v_internal_status := 'past_due';
    when 'canceled', 'cancelled', 'expired' then
      v_internal_status := 'canceled';
    when 'incomplete', 'incomplete_expired' then
      v_internal_status := 'incomplete';
    else
      v_internal_status := lower(p_status); -- Use as-is if not recognized
  end case;

  -- Check if subscription mapping already exists
  select id into v_payment_subscription_id
  from public.payment_subscriptions
  where (subscription_id = p_subscription_id and provider_id = p_provider_id)
     or external_subscription_id = p_external_subscription_id;

  if v_payment_subscription_id is not null then
    -- Update existing mapping
    update public.payment_subscriptions
    set 
      payment_account_id = p_payment_account_id,
      external_price_id = p_external_price_id,
      status = v_internal_status,
      provider_status = p_provider_status,
      current_period_start = p_current_period_start,
      current_period_end = p_current_period_end,
      cancel_at_period_end = p_cancel_at_period_end,
      canceled_at = p_canceled_at,
      metadata = p_metadata,
      updated_at = now()
    where id = v_payment_subscription_id;

    -- Update internal subscription status
    update public.org_product_subscriptions
    set 
      status = v_internal_status,
      updated_at = now()
    where id = p_subscription_id;
  else
    -- Insert new mapping
    insert into public.payment_subscriptions (
      subscription_id,
      provider_id,
      payment_account_id,
      external_subscription_id,
      external_price_id,
      status,
      provider_status,
      current_period_start,
      current_period_end,
      cancel_at_period_end,
      canceled_at,
      metadata
    )
    values (
      p_subscription_id,
      p_provider_id,
      p_payment_account_id,
      p_external_subscription_id,
      p_external_price_id,
      v_internal_status,
      p_provider_status,
      p_current_period_start,
      p_current_period_end,
      p_cancel_at_period_end,
      p_canceled_at,
      p_metadata
    )
    returning id into v_payment_subscription_id;

    -- Update internal subscription status
    update public.org_product_subscriptions
    set 
      status = v_internal_status,
      updated_at = now()
    where id = p_subscription_id;
  end if;

  return v_payment_subscription_id;
end;
$$;

comment on function public.sync_payment_subscription is 'Sync subscription status from payment provider webhook';

-- Function: Log webhook event (idempotent)
create or replace function public.log_payment_webhook_event(
  p_provider_id uuid,
  p_external_event_id text,
  p_event_type text,
  p_provider_event_type text,
  p_event_data jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
begin
  -- Check if event already exists (idempotency)
  select id into v_event_id
  from public.payment_webhook_events
  where provider_id = p_provider_id and external_event_id = p_external_event_id;

  if v_event_id is null then
    -- Insert new event
    insert into public.payment_webhook_events (
      provider_id,
      external_event_id,
      event_type,
      provider_event_type,
      event_data
    )
    values (
      p_provider_id,
      p_external_event_id,
      p_event_type,
      p_provider_event_type,
      p_event_data
    )
    returning id into v_event_id;
  end if;

  return v_event_id;
end;
$$;

comment on function public.log_payment_webhook_event is 'Log payment webhook event (idempotent)';

-- Function: Mark webhook event as processed
create or replace function public.mark_payment_webhook_processed(
  p_event_id uuid,
  p_error_message text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.payment_webhook_events
  set 
    processed = true,
    processed_at = now(),
    error_message = p_error_message
  where id = p_event_id;
end;
$$;

comment on function public.mark_payment_webhook_processed is 'Mark webhook event as processed';

-- Function: Sync payment invoice from webhook
create or replace function public.sync_payment_invoice(
  p_provider_id uuid,
  p_external_invoice_id text,
  p_amount_due bigint,
  p_status text,
  p_provider_status text,
  p_payment_account_id uuid default null,
  p_payment_subscription_id uuid default null,
  p_org_id uuid default null,
  p_amount_paid bigint default 0,
  p_currency text default 'usd',
  p_invoice_pdf text default null,
  p_hosted_invoice_url text default null,
  p_period_start timestamptz default null,
  p_period_end timestamptz default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id uuid;
  v_normalized_status text;
begin
  -- Map provider status to normalized status
  case lower(p_status)
    when 'paid', 'succeeded' then
      v_normalized_status := 'paid';
    when 'open', 'pending', 'unpaid' then
      v_normalized_status := 'open';
    when 'void', 'voided' then
      v_normalized_status := 'void';
    when 'uncollectible', 'failed' then
      v_normalized_status := 'uncollectible';
    else
      v_normalized_status := lower(p_status);
  end case;

  -- Check if invoice already exists
  select id into v_invoice_id
  from public.payment_invoices
  where external_invoice_id = p_external_invoice_id;

  if v_invoice_id is not null then
    -- Update existing invoice
    update public.payment_invoices
    set 
      payment_account_id = coalesce(p_payment_account_id, payment_account_id),
      payment_subscription_id = coalesce(p_payment_subscription_id, payment_subscription_id),
      org_id = coalesce(p_org_id, org_id),
      amount_due = p_amount_due,
      amount_paid = p_amount_paid,
      currency = p_currency,
      status = v_normalized_status,
      provider_status = p_provider_status,
      invoice_pdf = coalesce(p_invoice_pdf, invoice_pdf),
      hosted_invoice_url = coalesce(p_hosted_invoice_url, hosted_invoice_url),
      period_start = coalesce(p_period_start, period_start),
      period_end = coalesce(p_period_end, period_end),
      metadata = p_metadata,
      updated_at = now()
    where id = v_invoice_id;
  else
    -- Insert new invoice
    insert into public.payment_invoices (
      provider_id,
      payment_account_id,
      payment_subscription_id,
      org_id,
      external_invoice_id,
      amount_due,
      amount_paid,
      currency,
      status,
      provider_status,
      invoice_pdf,
      hosted_invoice_url,
      period_start,
      period_end,
      metadata
    )
    values (
      p_provider_id,
      p_payment_account_id,
      p_payment_subscription_id,
      p_org_id,
      p_external_invoice_id,
      p_amount_due,
      p_amount_paid,
      p_currency,
      v_normalized_status,
      p_provider_status,
      p_invoice_pdf,
      p_hosted_invoice_url,
      p_period_start,
      p_period_end,
      p_metadata
    )
    returning id into v_invoice_id;
  end if;

  return v_invoice_id;
end;
$$;

comment on function public.sync_payment_invoice is 'Sync payment invoice from webhook';

-- Grant execute permissions
grant execute on function public.sync_payment_account to authenticated;
grant execute on function public.sync_payment_product to authenticated;
grant execute on function public.sync_payment_price to authenticated;
grant execute on function public.sync_payment_subscription to authenticated;
grant execute on function public.log_payment_webhook_event to authenticated;
grant execute on function public.mark_payment_webhook_processed to authenticated;
grant execute on function public.sync_payment_invoice to authenticated;
