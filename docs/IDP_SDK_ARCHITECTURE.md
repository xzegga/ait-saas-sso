# IDP SDK Architecture Documentation

This document describes the architecture of the Identity Provider (IDP) SDK that allows external products to integrate authentication, user management, organization management, and billing functionality without implementing these features themselves.

---

## 🎯 Overview

The IDP SDK provides a **hybrid approach** combining:

1. **Complete UI Components** - Ready-to-use pages and components that products can integrate directly
2. **Programmatic Hooks** - Data fetching and business logic hooks for custom implementations

Products consuming the IDP can choose to:
- Use complete components "for free" (minimal integration effort)
- Use hooks programmatically (full UI customization)
- Mix both approaches (use components where needed, custom UI elsewhere)

---

## 🏗️ Architecture Principles

### 1. Zero Authentication Logic in Products
Products should never implement their own authentication. All authentication flows are handled by the IDP.

### 2. Centralized User and Organization Management
User profiles, organization profiles, and member management are provided by the IDP, ensuring consistency across all products.

### 3. Unified Billing System
All payment processing, subscription management, and invoicing is handled by the IDP, supporting multiple payment providers (Stripe, PayPal, etc.).

### 4. Permission-Based Access Control
Access control is based on JWT claims and product-specific roles configured in the IDP.

### 5. Provider-Agnostic Payment Handling
Payment methods are managed by third-party providers (Stripe, PayPal). The IDP only stores references and orchestrates the payment flow.

---

## 📦 SDK Structure

### Package Organization

The SDK is organized into logical modules:

- **Authentication Module**: Login, logout, OAuth, password management
- **Profile Module**: User and organization profiles
- **Organization Module**: Member management, invitations, role assignment
- **Billing Module**: Plans, subscriptions, payment methods, invoices
- **Permissions Module**: Access control and authorization helpers
- **Shared Module**: Common utilities, types, and providers

### Delivery Methods

The SDK can be consumed in two ways:

1. **NPM Package** (Recommended for React projects)
   - Install: `npm install @ait-saas-sso/idp-sdk`
   - Full TypeScript support
   - Tree-shakeable
   - Version control

2. **Micro Frontend (MFE)** (Optional)
   - Dynamic loading from Core
   - Automatic updates
   - Shared UI components
   - Requires Module Federation setup

---

## 🔐 Authentication Module

### Purpose
Handle all authentication flows without requiring products to implement login logic.

### Components Provided

#### LoginPage
Complete login page with:
- Email/password authentication
- OAuth provider buttons (Google, Facebook, GitHub, etc.)
- OAuth providers are configured in the Core, not hardcoded
- Error handling and validation
- Loading states
- Redirect after successful login

#### ForgotPasswordPage
Password recovery page with:
- Email input for password reset
- Email sending functionality
- Success/error feedback
- Link to return to login

#### OAuthCallback
Handles OAuth provider callbacks:
- Processes OAuth redirects
- Exchanges tokens
- Updates session
- Redirects to appropriate page

#### AuthGuard
Route protection component:
- Wraps protected routes
- Checks authentication status
- Redirects to login if not authenticated
- Optional redirect URL configuration

### Hooks Provided

#### useAuth
Returns authentication state:
- `isAuthenticated`: Boolean indicating if user is logged in
- `isLoading`: Loading state
- `user`: Current user object
- `error`: Any authentication errors

#### useLogin
Handles email/password login:
- Validates credentials
- Creates session
- Handles errors
- Callbacks for success/error

#### useLogout
Handles user logout:
- Clears session
- Clears local storage
- Redirects to login
- Optional callback

#### useOAuth
Initiates OAuth flow:
- Takes provider name (e.g., 'google', 'facebook')
- Redirects to provider
- Handles callback automatically

#### useForgotPassword
Sends password reset email:
- Validates email
- Sends reset link
- Handles success/error states

#### useResetPassword
Resets password with token:
- Validates token
- Updates password
- Handles success/error

#### useSession
Manages session state:
- Returns current session
- Auto-refreshes token
- Handles session expiration

### Features

- **OAuth Providers**: Configurable from Core (Google, Facebook, GitHub, etc.)
- **Consistent UI**: Same login experience across all products
- **Error Handling**: Comprehensive error messages and recovery
- **Security**: Token refresh, session management, secure storage
- **Customization**: Theme support, custom branding, callback customization

---

## 👤 Profile Module

### Purpose
Manage user and organization profiles without products implementing profile management.

### Components Provided

#### UserProfilePage
Complete user profile page with:
- View/edit user information (name, email, avatar)
- Change password functionality
- Avatar upload
- View user's organizations
- Switch between organizations
- Activity history (optional)

#### OrganizationProfilePage
Complete organization profile page with:
- View/edit organization information (name, billing email, MFA policy)
- View current plan and subscription
- View organization statistics (members, products, billing)
- Security settings
- Organization settings

### Hooks Provided

#### useUserProfile
Fetches current user profile data:
- User information
- Avatar URL
- Associated organizations
- Profile metadata

#### useUpdateProfile
Updates user profile:
- Name, email updates
- Avatar updates
- Validation
- Error handling

#### useChangePassword
Changes user password:
- Current password validation
- New password validation
- Password strength requirements
- Success/error feedback

#### useUploadAvatar
Handles avatar upload:
- File upload
- Image processing
- URL generation
- Error handling

#### useUserOrganizations
Lists user's organizations:
- All organizations user belongs to
- Current active organization
- Organization roles

#### useOrganization
Fetches organization data:
- Organization details
- Settings
- Metadata

#### useUpdateOrganization
Updates organization:
- Name, billing email updates
- MFA policy changes
- Settings updates
- Validation and error handling

#### useOrganizationStats
Fetches organization statistics:
- Member count
- Product count
- Subscription status
- Billing information

### Features

- **Unified Profile Management**: Consistent profile UI across products
- **Organization Switching**: Easy context switching between organizations
- **Avatar Management**: Built-in avatar upload and management
- **Security Settings**: MFA policy management at organization level
- **Statistics**: Quick overview of organization health

---

## 🏢 Organization Module

### Purpose
Manage organization members, invitations, and role assignments without products implementing team management.

### Components Provided

#### OrganizationMembersPage
Complete member management page with:
- List of all organization members
- Search and filter functionality
- Member details (name, email, roles, status)
- Invite new members
- Remove members
- Assign/update roles per product
- Activate/deactivate members
- View member permissions

#### InviteMemberDialog
Dialog for inviting new members:
- Email input
- Role selection
- Product role assignment
- Send invitation
- Success/error feedback

#### RoleAssignmentDialog
Dialog for assigning roles:
- Product selection
- Role selection (based on product role definitions)
- Assign/update roles
- View current roles

### Hooks Provided

#### useOrganizationMembers
Fetches organization members:
- List of members
- Member details
- Roles per product
- Status (active/inactive)
- Pagination support

#### useInviteMember
Sends member invitation:
- Email validation
- Role assignment
- Invitation creation
- Email sending
- Success/error handling

#### useRemoveMember
Removes member from organization:
- Validation (cannot remove last owner)
- Member removal
- Role cleanup
- Success/error feedback

#### useUpdateMemberRole
Updates member's role:
- Product-specific role updates
- Validation
- Permission updates
- Success/error handling

#### useMemberProductRoles
Fetches member's roles per product:
- All products member has access to
- Role for each product
- Permissions derived from roles

### Features

- **Complete Team Management**: Full CRUD for organization members
- **Role-Based Access**: Product-specific role assignment
- **Invitation System**: Email-based invitations with tokens
- **Permission Visibility**: See what each member can do
- **Bulk Operations**: Support for bulk role updates (future)

---

## 💳 Billing Module

### Purpose
Handle all payment and subscription management without products implementing billing logic.

### Payment Method Strategy

**Important**: Payment methods are NOT stored in our database. They are managed by third-party providers (Stripe, PayPal).

#### For Stripe:
- Payment methods are stored in Stripe's system
- We only store the `customer_id` (external_account_id)
- When creating subscriptions, we reference Stripe payment methods
- Payment methods are retrieved via Stripe API when needed

#### For PayPal:
- Payment methods are managed through PayPal billing agreements
- We store the billing agreement ID
- PayPal handles payment method storage internally
- Payment methods are retrieved via PayPal API when needed

### Components Provided

#### PlansCatalogPage
Complete plans catalog with:
- Display of all available plans for the product
- Prices per billing interval (month, year, custom)
- Plan comparison (features, entitlements)
- Highlight current plan
- Show discounts (e.g., annual vs monthly savings)
- Badges (Popular, Best Value, etc.)
- Filter and search functionality
- Call-to-action buttons (Subscribe, Current Plan, Upgrade)

#### SubscribeToPlanPage
Complete subscription page with:
- Plan summary (selected plan details)
- Billing interval selector
- Payment method selection/creation
  - If no payment account exists: Create one with provider
  - If payment account exists: Use existing or add new method
  - Redirects to provider for payment method setup
- Purchase summary
- Payment processing
- Success/error handling
- Redirect after successful subscription

#### SubscriptionManagementPage
Complete subscription management with:
- Current plan display
- Billing information (renewal date, billing period)
- Upgrade plan option (with preview of changes)
- Downgrade plan option (with preview of changes)
- Change billing interval (month ↔ year)
- Cancel subscription option:
  - Immediate cancellation
  - Cancel at period end (recommended)
- Resume subscription (if canceled)
- Confirmation dialogs for destructive actions

#### PaymentMethodsPage
Payment methods management with:
- List of payment methods from provider (via API)
- Display method details (last 4 digits, brand, expiry)
- Add new payment method button:
  - Redirects to provider (Stripe/PayPal) for setup
  - Returns with payment method reference
- Remove payment method (via provider API)
- Set default payment method
- Show which method is used in current subscription
- Note: Methods are not stored in our DB, only references

#### InvoicesPage
Complete invoices page with:
- List of invoices with pagination
- Filters (status, date range, amount)
- Invoice details (amount, currency, status, period)
- Download PDF functionality
- View hosted invoice (link to Stripe/PayPal invoice page)
- Retry failed payment
- Status badges (paid, pending, failed)
- Date formatting and currency display

### Hooks Provided

#### useProductPlans
Fetches available plans for product:
- All plans configured for the product
- Plan details (name, description, features)
- Optional: Include prices in response
- Optional: Include entitlements/features

#### usePlanPrices
Fetches prices for a specific plan:
- Prices per billing interval
- Currency information
- Optional: Calculate discounts (annual vs monthly)
- Default price identification

#### useBillingIntervals
Fetches available billing intervals:
- Active intervals (month, year, custom)
- Display labels
- Sort order
- Days calculation for comparisons

#### useCurrentSubscription
Fetches current organization subscription:
- Active subscription details
- Plan information
- Billing interval
- Renewal date
- Status (active, trial, past_due, canceled)
- Payment method reference

#### useSubscribeToPlan
Creates new subscription:
- Plan selection
- Billing interval selection
- Payment account creation/retrieval
- Payment method setup (via provider)
- Subscription creation
- Webhook processing
- Success/error handling

#### useUpgradeSubscription
Upgrades current subscription:
- New plan selection
- Proration calculation (optional)
- Billing interval change (optional)
- Preview of changes
- Confirmation
- Processing
- Success/error handling

#### useDowngradeSubscription
Downgrades current subscription:
- New plan selection
- Effective date (immediate or end of period)
- Preview of changes
- Confirmation
- Processing
- Success/error handling

#### useCancelSubscription
Cancels subscription:
- Cancel immediately or at period end
- Reason collection (optional)
- Confirmation dialog
- Processing
- Success/error handling

#### useResumeSubscription
Resumes canceled subscription:
- Validation (must be canceled)
- Resume processing
- Success/error handling

#### useUpdateBillingInterval
Changes billing interval:
- New interval selection
- Proration calculation
- Preview of changes
- Confirmation
- Processing
- Success/error handling

#### usePaymentAccount
Fetches/creates payment account:
- Get existing account for organization
- Create new account with provider if needed
- Account details (external_account_id, email, status)

#### usePaymentMethods
Fetches payment methods from provider:
- List methods from Stripe/PayPal API
- Method details (type, last4, brand, expiry)
- Default method identification
- Methods used in subscriptions

#### useAddPaymentMethod
Adds payment method via provider:
- Option A: Redirect to provider for setup
- Option B: Use provider SDK (e.g., Stripe Elements)
- Returns payment method reference
- Associates with payment account

#### useRemovePaymentMethod
Removes payment method:
- Calls provider API to remove
- Validates method is not in use
- Success/error handling

#### useSetDefaultPaymentMethod
Sets default payment method:
- Updates default in provider
- Updates subscription if needed
- Success/error handling

#### useInvoices
Fetches invoices:
- List of invoices with pagination
- Filters (status, date range, amount)
- Invoice details
- Total count

#### useInvoice
Fetches single invoice:
- Invoice details
- Line items
- Payment information
- Status

#### useDownloadInvoice
Downloads invoice PDF:
- Generates/downloads PDF
- Error handling

#### useRetryPayment
Retries failed payment:
- Validates invoice is failed
- Retries payment with provider
- Success/error handling

### Features

- **Multi-Provider Support**: Stripe, PayPal, and extensible to others
- **Dynamic Billing Intervals**: Configurable intervals (month, year, custom)
- **Automatic Renewals**: Handled by providers, synced via webhooks
- **Payment Method Management**: Via provider APIs, not stored locally
- **Invoice Management**: Complete invoice history and download
- **Subscription Lifecycle**: Full support for upgrade, downgrade, cancel, resume
- **Proration**: Automatic calculation for plan changes
- **Error Recovery**: Retry failed payments, handle webhook failures

---

## 🔒 Permissions Module

### Purpose
Provide access control and authorization helpers based on JWT claims and product roles.

### Components Provided

#### PermissionGate
Conditional rendering based on permissions:
- Wraps content that requires permission
- Checks permission before rendering
- Shows fallback if no permission
- Supports resource and action checks

#### FeatureFlag
Conditional rendering based on entitlements:
- Wraps content that requires feature
- Checks entitlement from plan
- Shows fallback if feature not available
- Supports feature key and value checks

### Hooks Provided

#### usePermissions
Returns current user permissions:
- Permissions from JWT claims
- Product-specific permissions
- Organization-level permissions
- Helper functions (hasPermission, canAccess)

#### useCan
Checks specific permission:
- Resource and action check
- Returns boolean
- Loading state
- Error handling

#### useHasRole
Checks if user has specific role:
- Role name check
- Product-specific role check
- Returns boolean

#### useHasFeature
Checks if plan includes feature:
- Feature key check
- Feature value check (if applicable)
- Returns boolean and value

#### useProductRoles
Fetches product role definitions:
- Available roles for product
- Role descriptions
- Role permissions (if configured)

### Features

- **JWT-Based**: Permissions derived from JWT claims
- **Product-Specific**: Roles defined per product
- **Plan-Based**: Features/entitlements from subscription plan
- **Granular Control**: Resource and action level permissions
- **UI Integration**: Components for conditional rendering

---

## 🔄 Integration Flows

### Authentication Flow

1. User visits product
2. Product checks authentication (via `useAuth` or `<AuthGuard>`)
3. If not authenticated, redirects to `<LoginPage />`
4. User logs in (email/password or OAuth)
5. IDP processes authentication
6. JWT token created with custom claims
7. User redirected back to product
8. Product reads JWT claims for permissions

### Subscription Flow

1. User visits `<PlansCatalogPage />`
2. User selects plan and billing interval
3. User navigates to `<SubscribeToPlanPage />`
4. If no payment account exists:
   - Create account with provider (Stripe/PayPal)
   - Store `external_account_id` in `payment_accounts`
5. Setup payment method:
   - Redirect to provider for payment method setup
   - Provider stores payment method
   - Return with payment method reference
6. Create subscription:
   - Create subscription in provider
   - Provider associates payment method
   - Store `external_subscription_id` in `payment_subscriptions`
   - Create internal subscription in `org_product_subscriptions`
7. Webhook processes subscription
8. User redirected to `<SubscriptionManagementPage />`

### Member Invitation Flow

1. Org Admin visits `<OrganizationMembersPage />`
2. Admin clicks "Invite Member"
3. `<InviteMemberDialog />` opens
4. Admin enters email and selects role
5. `useInviteMember` hook:
   - Creates invitation record
   - Sends email with invitation token
6. Invited user receives email
7. User clicks link, lands on invitation acceptance page
8. User logs in (if not already)
9. Invitation accepted via `accept_invitation` function
10. User added to organization
11. User redirected to product

---

## 🎨 Customization and Theming

### Theme System

The SDK uses CSS variables for theming:
- Primary colors
- Success/danger colors
- Font families
- Border styles
- Spacing

Products can override these variables to match their branding.

### Component Slots

Components support slots for custom content:
- Header slots
- Footer slots
- Custom card components
- Custom form fields

### Callbacks

Components support callbacks for custom logic:
- `onSuccess` callbacks
- `onError` callbacks
- `onBeforeAction` callbacks (for validation)
- `onAfterAction` callbacks (for analytics, etc.)

---

## 🔌 Provider Integration

### Payment Provider Integration

#### Stripe Integration
- Uses Stripe SDK for payment method collection
- Uses Stripe Checkout for subscription creation
- Webhooks for subscription updates
- Customer and subscription management via Stripe API

#### PayPal Integration
- Uses PayPal SDK for payment method collection
- Uses PayPal Billing Agreements for subscriptions
- Webhooks for subscription updates
- Customer and subscription management via PayPal API

### OAuth Provider Integration
- OAuth providers configured in Core
- Redirect URLs configured per product
- Token exchange handled by IDP
- User profile sync from OAuth providers

---

## 📊 Data Flow

### Authentication Data Flow

```
User → Product → IDP SDK → Supabase Auth → JWT with Claims → Product
```

### Subscription Data Flow

```
User → Product → IDP SDK → Payment Provider API → Webhook → IDP → Product
```

### Permission Data Flow

```
JWT Claims → IDP SDK → Permission Check → Product UI
```

---

## 🛡️ Security Considerations

### Token Management
- Tokens stored securely (httpOnly cookies recommended)
- Automatic token refresh
- Session expiration handling
- Secure token transmission

### Permission Validation
- All permissions validated server-side
- JWT claims verified on each request
- RLS policies enforce data access
- No client-side permission bypass possible

### Payment Security
- Payment methods never stored in our database
- Payment processing via secure provider APIs
- Webhook signature verification
- Idempotent webhook processing

---

## 📦 Package Structure

### Module Organization

```
@ait-saas-sso/idp-sdk/
├── hooks/              # All hooks organized by module
├── components/          # All components organized by module
├── providers/          # React context providers
├── utils/              # Utility functions
├── types/              # TypeScript type definitions
└── index.ts            # Main entry point
```

### Export Strategy

- **Named exports**: All hooks and components
- **Default exports**: Main providers
- **Tree-shakeable**: Only import what you need
- **TypeScript**: Full type definitions included

---

## 🚀 Implementation Phases

### Phase 1: Core Authentication (MVP)
- Basic login/logout
- Email/password authentication
- Session management
- Route protection

### Phase 2: OAuth and Profiles
- OAuth provider integration
- User profile management
- Organization profile management

### Phase 3: Organization Management
- Member management
- Invitations
- Role assignment

### Phase 4: Billing Foundation
- Plans catalog
- Basic subscription creation
- Current subscription view

### Phase 5: Advanced Billing
- Subscription management (upgrade/downgrade/cancel)
- Payment methods (via providers)
- Invoices

### Phase 6: Permissions and Polish
- Permission system
- Feature flags
- Error handling improvements
- Documentation

---

## 📝 Usage Patterns

### Pattern 1: Complete Components (For Free)

Products use complete components with minimal configuration:

```typescript
// Just configure and use
<IDPProvider config={...}>
  <Routes>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/profile" element={<UserProfilePage />} />
    <Route path="/plans" element={<PlansCatalogPage />} />
  </Routes>
</IDPProvider>
```

### Pattern 2: Programmatic (Custom UI)

Products use hooks to build custom UI:

```typescript
// Use hooks for data, build custom UI
const { plans } = useProductPlans();
const { subscribe } = useSubscribeToPlan();

// Build custom plan cards, checkout flow, etc.
```

### Pattern 3: Hybrid Approach

Products mix components and hooks:

```typescript
// Use components where convenient
<Route path="/login" element={<LoginPage />} />

// Use hooks for custom pages
function CustomDashboard() {
  const { user } = useAuth();
  const { subscription } = useCurrentSubscription();
  // Custom dashboard UI
}
```

---

## 🔄 Synchronization and Webhooks

### Webhook Processing

The IDP processes webhooks from payment providers:
- Subscription updates (created, updated, canceled)
- Payment updates (succeeded, failed)
- Invoice updates (paid, failed)
- Customer updates

Webhooks are:
- Logged in `payment_webhook_events`
- Processed idempotently
- Synchronized with internal data
- Retryable if processing fails

### Data Synchronization

- Payment data synced via webhooks
- Manual sync available via hooks
- Real-time updates via Supabase Realtime (optional)
- Conflict resolution handled automatically

---

## 📈 Scalability Considerations

### Performance
- Lazy loading of components
- Code splitting by module
- Optimistic updates where appropriate
- Caching of frequently accessed data

### Bundle Size
- Tree-shaking support
- Modular imports
- Optional dependencies
- Minimal runtime overhead

### Versioning
- Semantic versioning
- Backward compatibility
- Migration guides for breaking changes
- Support for multiple versions (if needed)

---

## 🧪 Testing Strategy

### Unit Tests
- Hook testing
- Utility function testing
- Type validation

### Integration Tests
- Component rendering
- Provider integration
- API interaction

### E2E Tests
- Complete user flows
- Payment flows
- Permission flows

---

## 📚 Documentation Requirements

### Developer Documentation
- Installation guide
- Quick start guide
- API reference
- Component documentation
- Hook documentation
- Examples and recipes

### Integration Guides
- React integration guide
- Next.js integration guide
- Customization guide
- Theming guide

### Troubleshooting
- Common issues
- Error handling
- Debugging tips
- Support channels

---

## 🔮 Future Enhancements

### Potential Additions
- Multi-factor authentication (MFA)
- Single Sign-On (SSO) between products
- Advanced analytics and reporting
- Webhook event replay
- Subscription usage tracking
- Custom billing intervals per plan
- Trial period management
- Coupon and discount codes
- Usage-based billing support

---

## 📋 Summary

The IDP SDK provides a comprehensive solution for products to integrate:

✅ **Authentication**: Complete login, OAuth, password management  
✅ **Profiles**: User and organization profile management  
✅ **Organization Management**: Member management, invitations, roles  
✅ **Billing**: Plans, subscriptions, payment methods, invoices  
✅ **Permissions**: Access control and authorization  

Products can choose to:
- Use complete components with minimal effort
- Use hooks for full UI customization
- Mix both approaches as needed

All functionality is:
- Secure (validated server-side)
- Consistent (same UI/UX across products)
- Maintainable (updates from IDP automatically)
- Extensible (easy to add new providers, features)

The SDK enables products to focus on their core business logic while leveraging enterprise-grade identity, user management, and billing infrastructure.
