# Granular Authorization Architecture

This document describes how the application combines Refine.dev's `<CanAccess>` component with granular permission checks using the `useCan` hook to implement a comprehensive, multi-level authorization system.

## Overview

The authorization system uses a **two-tier approach**:

1. **View-level access control**: `<CanAccess>` component wraps entire views/sections
2. **Action-level access control**: `useCan` hook provides granular permissions for specific actions (create, edit, delete)

This architecture allows different admin levels to access a resource but restricts modification, creation, or deletion based on their specific permissions.

## Architecture Components

### 1. Access Control Provider

The `accessControlProvider` (`apps/ait-sso-admin/src/providers/access-control.ts`) is the central authority for all permission checks.

#### Permission Structure

```typescript
interface UserPermissions {
  role: string | null;                    // e.g., "super_admin", "admin", "viewer"
  permissions?: Record<string, string[]>; // resource -> actions[]
}
```

**Current Implementation:**
- Only `super_admin` role exists
- `super_admin` has full access to all resources and actions
- Structure is prepared for future multi-level admin support

**Future Implementation:**
```typescript
{
  role: "admin",
  permissions: {
    "products": ["list", "show", "create", "edit"], // No delete
    "organizations": ["list", "show"],              // Read-only
    "users": ["list", "show", "edit"],              // No create/delete
  }
}
```

#### Permission Check Flow

```typescript
export const accessControlProvider: AccessControlProvider = {
  can: async ({ resource, action }) => {
    // 1. Get user permissions (cached)
    const { role, permissions } = await getUserPermissions();

    // 2. Check view access (for "list" or "show" actions)
    if (action === "list" || action === "show") {
      const hasAccess = hasPermission(role, permissions, resource, "list") ||
                       hasPermission(role, permissions, resource, "*");
      
      if (!hasAccess) {
        return { can: false, reason: `You don't have permission to view ${resource}` };
      }
    }

    // 3. Check specific action permission
    const canPerformAction = hasPermission(role, permissions, resource, action) ||
                            hasPermission(role, permissions, resource, "*");

    if (!canPerformAction) {
      return { can: false, reason: `You don't have permission to ${action} ${resource}` };
    }

    return { can: true };
  },
};
```

### 2. Hook Pattern

All custom hooks follow a consistent pattern for permission checks:

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

**Key Principles:**
- ✅ All `useCan` calls are made **inside the hook**, not in components
- ✅ Hooks expose permission flags to components
- ✅ Components never call `useCan` directly
- ✅ Permission checks are centralized and reusable

### 3. Component Pattern

Components use a two-level authorization approach:

#### Level 1: View Access with `<CanAccess>`

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

**Purpose:**
- Controls whether the entire view is accessible
- Shows `AccessDenied` component if user lacks view permission
- Prevents rendering of unauthorized content

#### Level 2: Action Permissions with Hook Values

```typescript
export const ProductList = () => {
  const { canCreate, canEdit, canDelete, ... } = useProducts();

  return (
    <CanAccess resource="products" action="list" fallback={<AccessDenied />}>
      <Card>
        <CardHeader>
          {/* Show create button only if user can create */}
          {canCreate?.can && (
            <Button onClick={handleCreate}>
              <Plus className="h-4 w-4 mr-2" />
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

**Purpose:**
- Controls visibility of action buttons (create, edit, delete)
- Allows read-only access for some users
- Provides granular control over specific operations

## Complete Example

### Product List Component

```typescript
"use client";

import { useState } from "react";
import { CanAccess } from "@refinedev/core";
import { AccessDenied } from "@/components/refine-ui/access-denied";
import { useProducts } from "@/hooks/useProducts";
import { ProductTable } from "@/components/products/product-table";

export const ProductList = () => {
  const {
    canAccess,
    canCreate,
    canEdit,
    canDelete,
    itemsList: products,
    isLoading,
    createItem,
    updateItem,
    softDeleteItem,
  } = useProducts();

  // Level 1: Wrap entire view with CanAccess
  return (
    <CanAccess
      resource="products"
      action="list"
      fallback={<AccessDenied resource="products" action="view" />}
    >
      <div className="space-y-6">
        <Card>
          <CardHeader>
            <div className="flex justify-between items-start">
              <div>
                <CardTitle>Products Management</CardTitle>
                <CardDescription>
                  Manage your platform products.
                </CardDescription>
              </div>
              {/* Level 2: Show create button only if user can create */}
              {canCreate?.can && (
                <Button onClick={handleCreate}>
                  <Plus className="h-4 w-4 mr-2" />
                  Add Product
                </Button>
              )}
            </div>
          </CardHeader>
          <CardContent>
            {/* Level 2: Pass granular permissions to child components */}
            <ProductTable
              items={products}
              canEdit={canEdit}
              canDelete={canDelete}
              onEdit={handleEdit}
              onDelete={handleSoftDelete}
            />
          </CardContent>
        </Card>
      </div>
    </CanAccess>
  );
};
```

### Product Table Component

```typescript
interface ProductTableProps {
  items: Product[];
  canEdit?: { can: boolean };
  canDelete?: { can: boolean };
  onEdit: (productId: string) => void;
  onDelete: (product: Product) => void;
}

export const ProductTable = ({
  items,
  canEdit,
  canDelete,
  onEdit,
  onDelete,
}: ProductTableProps) => {
  return (
    <Table>
      <TableBody>
        {items.map((product) => (
          <TableRow key={product.id}>
            <TableCell>{product.name}</TableCell>
            <TableCell className="text-center">
              <div className="flex items-center gap-2 justify-center">
                {/* Show edit button only if user can edit */}
                {canEdit?.can && (
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => onEdit(product.id)}
                  >
                    <Edit className="h-4 w-4" />
                  </Button>
                )}
                {/* Show delete button only if user can delete */}
                {canDelete?.can && (
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => onDelete(product)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                )}
              </div>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
};
```

## Permission Flow Diagram

```
User Action
    ↓
Component Renders
    ↓
<CanAccess> checks "list" permission
    ↓
    ├─→ No Access → Show <AccessDenied>
    │
    └─→ Has Access → Render Component
            ↓
        Hook calls useCan for each action
            ↓
        accessControlProvider.can() called
            ↓
        getUserPermissions() (cached)
            ↓
        hasPermission() checks role/permissions
            ↓
        Return permission flags
            ↓
        Component conditionally renders buttons
            ↓
        User sees only allowed actions
```

## Benefits of This Architecture

### 1. Separation of Concerns
- **View access**: Handled by `<CanAccess>` at the component level
- **Action permissions**: Handled by hooks and passed down as props
- **Permission logic**: Centralized in the access control provider

### 2. Reusability
- Hooks can be used across multiple components
- Permission checks are consistent across the application
- Easy to add new resources following the same pattern

### 3. Performance
- Permission checks are cached (see [Auth Request Optimization](./AUTH_REQUEST_OPTIMIZATION.md))
- No redundant API calls
- Fast permission evaluation

### 4. Maintainability
- Single source of truth for permissions
- Easy to update permission logic
- Clear separation between UI and authorization logic

### 5. Scalability
- Easy to add new roles and permissions
- Supports complex permission structures
- Prepared for future multi-level admin support

## Future Multi-Level Admin Support

When implementing multiple admin levels, update the `getUserPermissions` function:

```typescript
const getUserPermissions = async (): Promise<UserPermissions> => {
  const { user, session } = await getCachedAuth();
  if (!user || !session) return { role: null };

  const systemRole = getSystemRole(user, session.access_token);
  
  // Super admin has full access
  if (systemRole === "super_admin") {
    return { role: "super_admin" };
  }

  // Fetch permissions from database or JWT claims
  const permissions = await fetchUserPermissions(systemRole, user.id);
  
  return { role: systemRole, permissions };
};
```

**Permission Sources:**
- JWT claims: `user.app_metadata?.permissions`
- Database: Query `user_permissions` table
- External service: Fetch from permission service

## AccessDenied Component

A reusable component for displaying access denied messages:

```typescript
<AccessDenied 
  resource="products" 
  action="view" 
/>
```

**Location:** `apps/ait-sso-admin/src/components/refine-ui/access-denied.tsx`

**Features:**
- Consistent error messaging
- User-friendly interface
- Actionable error descriptions

## Checklist for New Resources

When adding a new resource, ensure:

- [ ] Hook calls `useCan` for all actions (list, create, edit, delete)
- [ ] Hook returns `canAccess`, `canCreate`, `canEdit`, `canDelete`
- [ ] Component wraps view with `<CanAccess>` component
- [ ] Component uses hook values to conditionally show/hide action buttons
- [ ] `AccessDenied` component is used as fallback in `<CanAccess>`
- [ ] Access control provider supports the new resource
- [ ] Child components receive permission props when needed

## Resources Using This Pattern

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

- [Authorization Pattern Guide](./AUTHORIZATION_PATTERN.md) - Implementation guide
- [Auth Request Optimization](./AUTH_REQUEST_OPTIMIZATION.md) - Performance optimization
- [Access Control Provider](../apps/ait-sso-admin/src/providers/access-control.ts) - Source code

## Conclusion

The granular authorization architecture provides a robust, scalable, and maintainable solution for managing user permissions. By combining `<CanAccess>` for view-level control and `useCan` for action-level permissions, the system supports both current requirements (super admin only) and future multi-level admin scenarios while maintaining excellent performance through intelligent caching.
