# Generic Payment System Documentation

This document explains how the generic payment system works and how it relates to the rest of the admin panel sections.

---

## 🎯 Overview

The payment system is designed to be **generic and extensible**, allowing integration of multiple payment providers (Stripe, PayPal, Razorpay, etc.) without needing to create provider-specific tables.

### Design Principles:
1. **Normalization:** States and data are normalized for cross-provider compatibility
2. **Extensibility:** Easy to add new providers without schema changes
3. **Traceability:** All webhook events are logged for debugging
4. **Idempotency:** Webhooks are processed idempotently

---

## 📊 Table Architecture

### 1. `payment_providers`
**Purpose:** Catalog of available payment providers

**Key fields:**
- `name`: Technical identifier (e.g., 'stripe', 'paypal')
- `display_name`: Display name for UI
- `status`: active, inactive, deprecated
- `config_schema`: JSON schema defining required configuration

**Relationships:**
- A payment account belongs to a provider
- A payment product belongs to a provider
- A payment price belongs to a provider
- A payment subscription belongs to a provider
- A payment invoice belongs to a provider
- A webhook event belongs to a provider

**In Admin:**
- Section: **Payment Providers** (already implemented)
- Allows creating/editing/deprecating providers
- Configure configuration schema

---

### 2. `payment_accounts`
**Purpose:** Organization payment accounts in providers

**Key fields:**
- `org_id`: Organization that owns the account
- `provider_id`: Payment provider
- `external_account_id`: Account ID in the provider (e.g., 'cus_xxx' in Stripe)
- `email`: Billing email
- `metadata`: Provider-specific data (payment methods, tax IDs, etc.)
- `status`: active, inactive, suspended

**Relationships:**
- An organization can have multiple accounts (one per provider)
- An account can have multiple subscriptions
- An account can have multiple invoices

**In Admin:**
- Section: **Payment Accounts** (pending)
- View all accounts by organization
- View all accounts by provider
- Create/edit accounts
- View associated subscriptions and invoices

**Relationship with other sections:**
- **Organizations:** View associated payment account
- **Subscriptions:** View organization's payment account
- **Invoices:** View account that generated the invoice

---

### 3. `payment_products`
**Purpose:** Mapping of internal products to provider products

**Key fields:**
- `product_id`: Internal product
- `provider_id`: Payment provider
- `external_product_id`: Product ID in the provider (e.g., 'prod_xxx' in Stripe)
- `metadata`: Provider-specific data

**Relationships:**
- An internal product can be mapped to multiple providers
- A payment product can have multiple prices

**In Admin:**
- Section: **Payment Products** (pending)
- View which products are synchronized with which providers
- Create/edit mappings
- View provider metadata

**Relationship with other sections:**
- **Products:** View payment product mappings
- **Payment Prices:** View associated payment product

---

### 4. `payment_prices`
**Purpose:** Mapping of plans to provider prices

**Key fields:**
- `product_plan_id`: Internal product-plan relationship
- `provider_id`: Payment provider
- `external_price_id`: Price ID in the provider (e.g., 'price_xxx' in Stripe)
- `external_product_id`: Reference to payment product
- `billing_interval`: References `billing_intervals.key` (dynamic, not hardcoded)
- `currency`: Currency code
- `amount`: Amount in cents or smallest currency unit
- `metadata`: Provider-specific data

**Relationships:**
- An internal plan can have multiple prices (one per provider)
- A payment price belongs to a payment product
- A payment price can have multiple subscriptions

**Important:** The `billing_interval` field references the `billing_intervals` table, allowing dynamic billing intervals (month, year, two_years, etc.) instead of hardcoded values.

**In Admin:**
- Section: **Payment Prices** (pending)
- View prices per plan and provider
- Create/edit mappings
- View billing intervals and currencies

**Relationship with other sections:**
- **Product Plans:** View associated payment prices
- **Payment Subscriptions:** View payment price used

---

### 5. `payment_subscriptions`
**Purpose:** Subscriptions synchronized with payment providers

**Key fields:**
- `subscription_id`: Internal subscription (`org_product_subscriptions.id`)
- `provider_id`: Payment provider
- `payment_account_id`: Payment account
- `external_subscription_id`: Subscription ID in the provider (e.g., 'sub_xxx' in Stripe)
- `external_price_id`: Price used
- `status`: Normalized status (active, trial, past_due, canceled, incomplete)
- `provider_status`: Original provider status (for debugging)
- `current_period_start/end`: Current billing period
- `cancel_at_period_end`: If scheduled to cancel
- `canceled_at`: Cancellation date
- `metadata`: Provider-specific data

**Relationships:**
- An internal subscription can have multiple payment subscriptions (one per provider)
- A payment subscription belongs to a payment account
- A payment subscription can have multiple invoices

**In Admin:**
- Section: **Payment Subscriptions** (pending)
- View all synchronized subscriptions
- Filter by organization, provider, status
- View normalized status vs provider_status
- View billing periods
- Link to internal subscription

**Relationship with other sections:**
- **Subscriptions:** View associated payment subscription
- **Organizations:** View organization's payment subscriptions
- **Payment Accounts:** View account's subscriptions
- **Invoices:** View subscription that generated the invoice

---

### 6. `payment_invoices`
**Purpose:** Invoices from payment providers

**Key fields:**
- `provider_id`: Payment provider
- `payment_account_id`: Payment account
- `payment_subscription_id`: Payment subscription (optional)
- `org_id`: Organization (for quick access)
- `external_invoice_id`: Invoice ID in the provider (e.g., 'in_xxx' in Stripe)
- `amount_due`: Amount due in cents
- `amount_paid`: Amount paid in cents
- `currency`: Currency code
- `status`: Normalized status (draft, open, paid, void, uncollectible)
- `provider_status`: Original provider status
- `invoice_pdf`: URL to invoice PDF
- `hosted_invoice_url`: URL to invoice page
- `period_start/end`: Billed period
- `metadata`: Provider-specific data

**Relationships:**
- An invoice belongs to a provider
- An invoice can belong to a payment account
- An invoice can belong to a payment subscription
- An invoice belongs to an organization

**In Admin:**
- Section: **Billing/Invoices** (implemented, uses generic `usePaymentInvoices`)
- View all invoices
- Filter by organization, provider, status
- Download PDFs
- View hosted invoice URLs
- View billed period

**Relationship with other sections:**
- **Organizations:** View organization's invoices
- **Subscriptions:** View subscription's invoices
- **Payment Accounts:** View account's invoices
- **Payment Subscriptions:** View payment subscription's invoices

---

### 7. `payment_webhook_events`
**Purpose:** Log of webhook events from all providers

**Key fields:**
- `provider_id`: Payment provider
- `external_event_id`: Event ID in the provider (e.g., 'evt_xxx' in Stripe)
- `event_type`: Normalized type (e.g., 'subscription.created', 'invoice.paid')
- `provider_event_type`: Original provider type (e.g., 'customer.subscription.created' in Stripe)
- `processed`: Whether the event was processed
- `processed_at`: Processing date
- `event_data`: Complete webhook payload (JSONB)
- `error_message`: Error message if processing failed

**Relationships:**
- An event belongs to a provider
- An event can be related to multiple entities (account, subscription, invoice)

**In Admin:**
- Section: **Payment Webhook Events** (pending)
- View all received events
- Filter by provider, type, status
- View complete payload
- Re-process failed events
- Event statistics

**Relationship with other sections:**
- **Payment Providers:** View provider's events
- **Payment Subscriptions:** View related events
- **Invoices:** View related events

---

## 🔄 Synchronization Flows

### Flow 1: Create Subscription
1. Super Admin creates subscription in **Subscriptions** (`org_product_subscriptions`)
2. If payment provider is configured:
   - Create/update `payment_account` (if it doesn't exist)
   - Create/update `payment_product` (product mapping)
   - Create/update `payment_price` (plan mapping)
   - Create `payment_subscription` (synchronization)
3. Provider webhook confirms creation
4. Status is updated in both tables (internal and payment)

### Flow 2: Invoice Webhook
1. Provider sends invoice created/paid webhook
2. Event is logged in `payment_webhook_events`
3. Event is processed:
   - Create/update `payment_invoice`
   - Update `payment_subscription` status if applicable
   - Update `org_product_subscriptions` status if applicable
4. Event is marked as processed

### Flow 3: Subscription Status Change
1. Provider sends webhook (e.g., subscription.canceled)
2. Event is logged in `payment_webhook_events`
3. `payment_subscription.status` is updated (normalized)
4. `org_product_subscriptions.status` is updated (synchronized)
5. Event is marked as processed

---

## 🔗 Relationships with Other Sections

### Organizations
- **View:** Associated payment account (`payment_accounts`)
- **View:** Active payment subscriptions (`payment_subscriptions`)
- **View:** Billing history (`payment_invoices`)
- **View:** Total spent (sum of paid invoices)

### Subscriptions (`org_product_subscriptions`)
- **View:** Associated payment subscription (`payment_subscriptions`)
- **View:** Related invoices (`payment_invoices`)
- **View:** Synchronized status vs internal status
- **Synchronize:** Manually if there's desynchronization

### Products
- **View:** Payment product mappings (`payment_products`)
- **View:** Which providers have this product synchronized

### Product Plans
- **View:** Associated payment prices (`payment_prices`)
- **View:** Which providers have this plan with price
- **Note:** Product plans are managed within the Products section, not as a separate page

### Billing Intervals
- **Purpose:** Dynamic billing interval configuration (month, year, custom intervals)
- **Location:** Plans & Entitlements → Billing Intervals tab
- **Relationship:** `payment_prices.billing_interval` references `billing_intervals.key`
- **Default values:** Only "month" and "year" (day and week removed)

### Payment Providers
- **View:** Created accounts (`payment_accounts`)
- **View:** Synchronized products (`payment_products`)
- **View:** Configured prices (`payment_prices`)
- **View:** Active subscriptions (`payment_subscriptions`)
- **View:** Webhook events (`payment_webhook_events`)

---

## 🛠️ Synchronization Functions

All functions are in `supabase/migrations/20250101000012_functions_payment_sync.sql`:

### `sync_payment_account(org_id, provider_id, external_account_id, ...)`
Creates or updates a payment account for an organization.

### `sync_payment_product(product_id, provider_id, external_product_id, ...)`
Creates or updates the mapping of an internal product to a provider product.

### `sync_payment_price(product_plan_id, provider_id, external_price_id, ...)`
Creates or updates the mapping of a plan to a provider price.

### `sync_payment_subscription(subscription_id, provider_id, ...)`
Creates or updates a payment subscription and synchronizes status with the internal subscription.

### `sync_payment_invoice(provider_id, external_invoice_id, ...)`
Creates or updates a payment invoice from a webhook.

### `log_payment_webhook_event(provider_id, external_event_id, ...)`
Logs a webhook event (idempotent).

### `mark_payment_webhook_processed(event_id, error_message)`
Marks an event as processed.

---

## 🔐 Security (RLS)

### Super Admins
- Full access to all payment tables
- Can view all data from all organizations

### Org Admins (Owners)
- Can only view data from their own organizations
- Can view:
  - `payment_accounts` of their org
  - `payment_subscriptions` of their org
  - `payment_invoices` of their org
- Cannot create/edit (only super admins)

### Service Role
- Can insert/update for webhook processing
- Used by Edge Functions that process webhooks

---

## 📝 Status Normalization

### Subscription Status
- **Provider → Normalized:**
  - `active`, `trialing` → `active`
  - `past_due`, `unpaid`, `payment_failed` → `past_due`
  - `canceled`, `cancelled`, `expired` → `canceled`
  - `incomplete`, `incomplete_expired` → `incomplete`

### Invoice Status
- **Provider → Normalized:**
  - `paid`, `succeeded` → `paid`
  - `open`, `pending`, `unpaid` → `open`
  - `void`, `voided` → `void`
  - `uncollectible`, `failed` → `uncollectible`

---

## 🚀 Next Steps

1. **Implement Payment Accounts** (high priority)
2. **Implement Payment Subscriptions** (high priority)
3. **Implement Payment Webhook Events** (high priority)
4. **Implement Payment Products** (medium priority)
5. **Implement Payment Prices** (medium priority)
6. **Add links between sections** (improvements)

---

## 📚 Related Documentation

- [Admin Pending Features](./ADMIN_PENDING_FEATURES.md) - Implementation roadmap
- [Granular Authorization](./GRANULAR_AUTHORIZATION.md) - Authorization system
- [Auth Request Optimization](./AUTH_REQUEST_OPTIMIZATION.md) - Performance optimization

---

**Last updated:** 2025-01-XX
**Version:** 2.0
