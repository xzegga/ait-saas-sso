# Authorization Pattern Guide

This document describes the authorization pattern implemented in the admin application using Refine.dev's `<CanAccess>` component and `useCan` hook.

## Overview

The application uses a **two-level authorization approach**:

1. **View-level access control**: Using `<CanAccess>` component to wrap entire views/sections
2. **Action-level access control**: Using `useCan` hook for granular permissions on specific actions (create, edit, delete)

This pattern allows different admin levels to access a resource but restricts modification, creation, or deletion based on their permissions.

## Architecture

### Access Control Provider

The `accessControlProvider` in `apps/ait-sso-admin/src/providers/access-control.ts` handles all permission checks:

- **Current implementation**: Only `super_admin` role has full access
- **Future-ready**: Designed to support multiple admin levels with granular permissions
- **Permission structure**: 
  - `role`: User's role (e.g., "super_admin", "admin", "viewer")
  - `permissions`: Optional object mapping resources to allowed actions (e.g., `{ "products": ["list", "show"] }`)
  - Wildcard `"*"` action means full access to a resource

### Hook Pattern

All custom hooks follow this pattern:

```typescript
export const useProducts = (props?: UseProductsProps) => {
  // Granular permission checks - all useCan calls in the hook
  const { data: canAccess } = useCan({ resource: "products", action: "list" });
  const { data: canCreate } = useCan({ resource: "products", action: "create" });
  const { data: canEdit } = useCan({ resource: "products", action: "edit" });
  const { data: canDelete } = useCan({ resource: "products", action: "delete" });

  // ... rest of hook logic

  return {
    canAccess,
    canCreate,
    canEdit,
    canDelete,
    // ... other return values
  };
};
```

**Key points:**
- All `useCan` calls are made **inside the hook**, not in components
- Hooks expose `canAccess`, `canCreate`, `canEdit`, `canDelete` to components
- Components use these values directly without calling `useCan` again

### Component Pattern

Components use a two-level approach:

#### 1. View-level: Wrap with `<CanAccess>`

```typescript
import { CanAccess } from "@refinedev/core";
import { AccessDenied } from "@/components/refine-ui/access-denied";

export const ProductList = () => {
  const { canAccess, canCreate, canEdit, canDelete, ... } = useProducts();

  return (
    <CanAccess
      resource="products"
      action="list"
      fallback={<AccessDenied resource="products" action="view" />}
    >
      <div className="space-y-6">
        {/* Component content */}
      </div>
    </CanAccess>
  );
};
```

#### 2. Action-level: Use hook values for buttons/actions

```typescript
// Show/hide create button
{canCreate?.can && (
  <Button onClick={handleCreate}>
    <Plus className="h-4 w-4 mr-2" />
    Add Product
  </Button>
)}

// Show/hide edit button
{canEdit?.can && (
  <Button onClick={() => handleEdit(item.id)}>
    <Edit className="h-4 w-4" />
  </Button>
)}

// Show/hide delete button
{canDelete?.can && (
  <Button onClick={() => handleDelete(item)}>
    <Trash2 className="h-4 w-4" />
  </Button>
)}
```

## Implementation Examples

### Example 1: Products List

**File**: `apps/ait-sso-admin/src/pages/products/list.tsx`

```typescript
export const ProductList = () => {
  const { canAccess, canCreate, canEdit, canDelete, ... } = useProducts();

  return (
    <CanAccess
      resource="products"
      action="list"
      fallback={<AccessDenied resource="products" action="view" />}
    >
      <Card>
        <CardHeader>
          {canCreate?.can && (
            <Button onClick={handleCreate}>
              Add Product
            </Button>
          )}
        </CardHeader>
        <CardContent>
          <ProductTable
            canEdit={canEdit}
            canDelete={canDelete}
            // ... other props
          />
        </CardContent>
      </Card>
    </CanAccess>
  );
};
```

### Example 2: Billing Intervals Section

**File**: `apps/ait-sso-admin/src/pages/plans-entitlements/components/billing-intervals-section.tsx`

```typescript
export const BillingIntervalsSection = () => {
  const {
    canAccess,
    canCreate,
    canEdit,
    canDelete,
    // ... other values
  } = useBillingIntervals({ activeOnly: false });

  return (
    <CanAccess
      resource="billing-intervals"
      action="list"
      fallback={<AccessDenied resource="billing-intervals" action="view" />}
    >
      <div className="space-y-4">
        {canCreate?.can && (
          <Button onClick={handleCreate}>
            Add Interval
          </Button>
        )}
        
        <Table>
          {/* ... table rows */}
          {canEdit?.can && <EditButton />}
          {canDelete?.can && <DeleteButton />}
        </Table>
      </div>
    </CanAccess>
  );
};
```

## AccessDenied Component

A reusable component for displaying access denied messages:

**File**: `apps/ait-sso-admin/src/components/refine-ui/access-denied.tsx`

```typescript
<AccessDenied 
  resource="products" 
  action="view" 
/>
```

## Future Multi-Level Admin Support

When implementing multiple admin levels, update the `getUserPermissions` function in `access-control.ts`:

```typescript
const getUserPermissions = async (): Promise<{
  role: string | null;
  permissions?: Record<string, string[]>;
}> => {
  // Get role from JWT or database
  const role = getSystemRole(user, accessToken);
  
  if (role === "super_admin") {
    return { role: "super_admin" }; // Full access
  }

  // For other roles, fetch permissions from:
  // - JWT claims: user.app_metadata?.permissions
  // - Database: query user_permissions table
  // - External service: fetch from permission service
  
  const permissions = await fetchUserPermissions(role);
  return { role, permissions };
};
```

Example permissions structure:
```typescript
{
  role: "admin",
  permissions: {
    "products": ["list", "show", "create", "edit"], // No delete
    "organizations": ["list", "show"], // Read-only
    "users": ["list", "show", "edit"], // No create/delete
  }
}
```

## Checklist for New Resources

When adding a new resource, ensure:

- [ ] Hook calls `useCan` for all actions (list, create, edit, delete)
- [ ] Hook returns `canAccess`, `canCreate`, `canEdit`, `canDelete`
- [ ] Component wraps view with `<CanAccess>` component
- [ ] Component uses hook values to conditionally show/hide action buttons
- [ ] `AccessDenied` component is used as fallback in `<CanAccess>`
- [ ] Access control provider supports the new resource

## Resources Updated

The following resources have been updated with this pattern:

- ✅ Products (`useProducts`, `ProductList`)
- ✅ Billing Intervals (`useBillingIntervals`, `BillingIntervalsSection`)
- ✅ Organizations (`useOrganizations`)
- ✅ Plans (`usePlans`)
- ✅ Entitlements (`useEntitlements`)
- ✅ Product Plans (`useProductPlans`)
- ✅ Payment Providers (`usePaymentProviders`)
- ✅ Users (`useUsers`)
- ✅ Member Product Roles (`useMemberProductRoles`)
- ✅ Payment Invoices (`usePaymentInvoices`)

## Related Documentation

- [Granular Authorization](./GRANULAR_AUTHORIZATION.md) - Comprehensive authorization architecture
- [Auth Request Optimization](./AUTH_REQUEST_OPTIMIZATION.md) - Performance optimization for auth calls
- [Access Control Provider](../apps/ait-sso-admin/src/providers/access-control.ts) - Implementation details

## Notes

- Currently, only `super_admin` has access to all resources and actions
- The pattern is designed to be future-ready for multi-level admin support
- All permission checks are centralized in the access control provider
- Components should never call `useCan` directly; always use values from hooks
- Authentication requests are optimized with caching and request deduplication (see [Auth Request Optimization](./AUTH_REQUEST_OPTIMIZATION.md))
