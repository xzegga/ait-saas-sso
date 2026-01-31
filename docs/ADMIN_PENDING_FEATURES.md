# Work Plan - Pending Admin Panel Features

This document details all pending features to be implemented in the admin panel, prioritized and organized by categories.

---

## 📊 Current Status

### ✅ Implemented (13 pages)
1. **Dashboard** - General statistics
2. **Products** - Full CRUD with plan and role management
3. **Plans & Entitlements** - Global plans and entitlements management
4. **Billing Intervals** - Dynamic billing interval configuration (month, year, and custom intervals)
5. **Organizations** - Listing and management
6. **Organization Members** - Member management per organization
7. **Member Product Roles** - Role assignment per product
8. **Subscriptions** - Listing, creation, and editing
9. **Users/Profiles** - Listing and details
10. **Super Admins** - Whitelist management
11. **Recycle Bin** - Deleted items management
12. **Billing/Invoices** - Invoices (migrated to generic `usePaymentInvoices`)
13. **Payment Providers** - Payment providers CRUD

---

## 🚨 High Priority

### 1. Payment Accounts (`payment_accounts`)
**Purpose:** View and manage payment accounts per organization

**Required functionality:**
- [ ] List all payment accounts
- [ ] Filter by organization
- [ ] Filter by provider
- [ ] View account details (external_account_id, metadata, status)
- [ ] Create/edit accounts (associate org with provider account)
- [ ] View payment history per account
- [ ] View subscriptions associated with the account

**Files to create:**
- `apps/ait-sso-admin/src/hooks/usePaymentAccounts.ts`
- `apps/ait-sso-admin/src/pages/payment-accounts/list.tsx`
- `apps/ait-sso-admin/src/components/payment-accounts/*`

**Estimation:** 4-6 hours

---

### 2. Payment Subscriptions (`payment_subscriptions`)
**Purpose:** View subscriptions synchronized with payment providers

**Required functionality:**
- [ ] List all payment subscriptions
- [ ] Filter by organization
- [ ] Filter by provider
- [ ] Filter by status (active, trial, past_due, canceled)
- [ ] View normalized status vs provider_status
- [ ] View billing periods (current_period_start, current_period_end)
- [ ] View if scheduled to cancel (cancel_at_period_end)
- [ ] Link to internal subscription (`org_product_subscriptions`)
- [ ] Manually synchronize if needed

**Files to create:**
- `apps/ait-sso-admin/src/hooks/usePaymentSubscriptions.ts`
- `apps/ait-sso-admin/src/pages/payment-subscriptions/list.tsx`
- `apps/ait-sso-admin/src/components/payment-subscriptions/*`

**Estimation:** 5-7 hours

---

### 3. Payment Webhook Events (`payment_webhook_events`)
**Purpose:** Debugging and monitoring of payment provider webhooks

**Required functionality:**
- [ ] List all received events
- [ ] Filter by provider
- [ ] Filter by event type (event_type)
- [ ] Filter by status (processed/unprocessed)
- [ ] View complete event payload
- [ ] View error_message if processing failed
- [ ] Manually re-process failed events
- [ ] Event statistics (total, processed, failed)
- [ ] Search by external_event_id

**Files to create:**
- `apps/ait-sso-admin/src/hooks/usePaymentWebhookEvents.ts`
- `apps/ait-sso-admin/src/pages/payment-webhook-events/list.tsx`
- `apps/ait-sso-admin/src/components/payment-webhook-events/*`

**Estimation:** 6-8 hours

---

## 📋 Medium Priority

### 4. Payment Products (`payment_products`)
**Purpose:** Map internal products to provider products

**Required functionality:**
- [ ] List all product → provider product mappings
- [ ] Filter by internal product
- [ ] Filter by provider
- [ ] Create/edit mappings
- [ ] View which products are synchronized with which providers
- [ ] View provider metadata

**Files to create:**
- `apps/ait-sso-admin/src/hooks/usePaymentProducts.ts`
- `apps/ait-sso-admin/src/pages/payment-products/list.tsx`
- `apps/ait-sso-admin/src/components/payment-products/*`

**Estimation:** 3-4 hours

---

### 5. Payment Prices (`payment_prices`)
**Purpose:** Map plans to provider prices

**Required functionality:**
- [ ] List all plan → provider price mappings
- [ ] Filter by internal product-plan
- [ ] Filter by provider
- [ ] Create/edit mappings
- [ ] View prices per provider and plan
- [ ] View billing_interval (references dynamic billing_intervals table)
- [ ] View amount in cents and currency

**Files to create:**
- `apps/ait-sso-admin/src/hooks/usePaymentPrices.ts`
- `apps/ait-sso-admin/src/pages/payment-prices/list.tsx`
- `apps/ait-sso-admin/src/components/payment-prices/*`

**Estimation:** 3-4 hours

---

### 6. Role Templates (`role_templates`)
**Purpose:** Reusable role templates for products

**Status:** Hook exists (`useRoleTemplates`), page is missing

**Required functionality:**
- [ ] List all templates
- [ ] Create/edit/delete templates
- [ ] View roles included in each template
- [ ] Apply template to a product
- [ ] Preview which roles will be created

**Files to create:**
- `apps/ait-sso-admin/src/pages/role-templates/list.tsx`
- `apps/ait-sso-admin/src/components/role-templates/*`

**Estimation:** 3-4 hours

---

## 🔧 Improvements to Existing Pages

### 7. Subscriptions Improvements
**Additional functionality:**
- [ ] View associated payment subscription (link to `payment_subscriptions`)
- [ ] View status change history
- [ ] View related invoices
- [ ] View associated payment account

**Files to modify:**
- `apps/ait-sso-admin/src/pages/subscriptions/list.tsx`
- `apps/ait-sso-admin/src/components/subscriptions/*`

**Estimation:** 2-3 hours

---

### 8. Organizations Improvements
**Additional functionality:**
- [ ] View associated payment account (link to `payment_accounts`)
- [ ] View active payment subscriptions
- [ ] View billing history
- [ ] View total spent per organization

**Files to modify:**
- `apps/ait-sso-admin/src/pages/organizations/list.tsx`
- `apps/ait-sso-admin/src/components/organizations/*`

**Estimation:** 2-3 hours

---

## 📝 Implementation Notes

### Patterns to follow:
1. **Hooks:** Use the same pattern as `usePaymentProviders` for consistency
2. **Components:** Reuse components from `payment-providers` as base
3. **Filters:** Implement filters by organization, provider, status
4. **Tables:** Display key information with links to related entities
5. **Forms:** Use Sheets for create/edit, similar to other pages
6. **Authorization:** Use `<CanAccess>` and granular `useCan` hooks (see [Granular Authorization](./GRANULAR_AUTHORIZATION.md))

### Technical considerations:
- All payment tables have RLS enabled
- Super admins have full access
- Org admins only see data from their organizations
- Service role can insert/update for webhooks
- Authorization uses granular permissions (view, create, edit, delete)

### Suggested implementation order:
1. Payment Accounts (base for everything else)
2. Payment Subscriptions (most used)
3. Payment Webhook Events (critical debugging)
4. Payment Products and Prices (complete mappings)
5. Role Templates (independent functionality)
6. Improvements to existing pages (final polish)

---

## 📊 Estimation Summary

| Priority | Feature | Estimation |
|----------|---------|------------|
| High | Payment Accounts | 4-6 hours |
| High | Payment Subscriptions | 5-7 hours |
| High | Payment Webhook Events | 6-8 hours |
| Medium | Payment Products | 3-4 hours |
| Medium | Payment Prices | 3-4 hours |
| Medium | Role Templates | 3-4 hours |
| Low | Subscriptions Improvements | 2-3 hours |
| Low | Organizations Improvements | 2-3 hours |
| **TOTAL** | | **29-40 hours** |

---

## ✅ Recently Completed

- **Billing Intervals**: Dynamic billing interval management (month, year, and custom intervals)
- **Product Plans**: Integrated into Products section (not a separate page)
- **Payment Invoices**: Migrated to generic system (`usePaymentInvoices`)
- **Authorization System**: Implemented granular authorization with `<CanAccess>` and `useCan`
- **Auth Optimization**: Implemented request deduplication to prevent duplicate API calls

---

**Last updated:** 2025-01-XX
**Status:** In progress - Billing Intervals and Authorization System completed ✅
