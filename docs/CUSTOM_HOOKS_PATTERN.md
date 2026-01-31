# Custom Hooks Pattern for Business Logic Separation

This document describes the architectural pattern of separating business logic, data fetching, and CRUD operations into custom hooks instead of implementing them directly in page components. This pattern promotes code reusability, testability, and maintainability.

---

## 🎯 Overview

The **Custom Hooks Pattern** is a React architectural approach that separates:
- **Business Logic**: Data fetching, mutations, state management
- **Presentation Logic**: UI rendering, user interactions, visual feedback

By encapsulating business logic in custom hooks, we create reusable, testable, and maintainable code that can be shared across multiple components.

---

## 📐 Architecture Pattern

### Traditional Approach (Not Recommended)

```typescript
// ❌ Business logic mixed with presentation
export const ProductList = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLoading(true);
    fetch('/api/products')
      .then(res => res.json())
      .then(data => {
        setProducts(data);
        setLoading(false);
      })
      .catch(err => {
        setError(err);
        setLoading(false);
      });
  }, []);

  const handleDelete = async (id) => {
    await fetch(`/api/products/${id}`, { method: 'DELETE' });
    setProducts(products.filter(p => p.id !== id));
  };

  return (
    <div>
      {loading && <Spinner />}
      {error && <Error message={error} />}
      {products.map(product => (
        <ProductCard key={product.id} product={product} onDelete={handleDelete} />
      ))}
    </div>
  );
};
```

**Problems:**
- Logic is tightly coupled to the component
- Difficult to reuse in other components
- Hard to test business logic separately
- Component becomes bloated and hard to maintain

### Custom Hooks Pattern (Recommended)

```typescript
// ✅ Business logic in custom hook
export const useProducts = (props?: UseProductsProps) => {
  const { pageSize = 10, currentPage = 1, searchQuery = "" } = props || {};
  
  // Data fetching logic
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['products', currentPage, searchQuery],
    queryFn: () => fetchProducts({ page: currentPage, search: searchQuery }),
  });

  // Mutation logic
  const createMutation = useMutation({
    mutationFn: createProduct,
    onSuccess: () => refetch(),
  });

  const updateMutation = useMutation({
    mutationFn: updateProduct,
    onSuccess: () => refetch(),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteProduct,
    onSuccess: () => refetch(),
  });

  // Computed values
  const totalPages = Math.ceil((data?.total || 0) / pageSize);

  // Exposed API
  return {
    // Data
    itemsList: data?.items || [],
    total: data?.total || 0,
    
    // Loading states
    isLoading,
    isCreating: createMutation.isPending,
    isUpdating: updateMutation.isPending,
    isDeleting: deleteMutation.isPending,
    
    // Error states
    isError: !!error,
    error,
    
    // Actions
    createItem: createMutation.mutate,
    updateItem: updateMutation.mutate,
    deleteItem: deleteMutation.mutate,
    refetch,
    
    // Computed
    totalPages,
  };
};

// ✅ Presentation logic in component
export const ProductList = () => {
  const {
    itemsList: products,
    isLoading,
    isDeleting,
    deleteItem,
  } = useProducts();

  const handleDelete = (id: string) => {
    deleteItem(id);
  };

  return (
    <div>
      {isLoading && <Spinner />}
      {products.map(product => (
        <ProductCard key={product.id} product={product} onDelete={handleDelete} />
      ))}
    </div>
  );
};
```

**Benefits:**
- Logic is reusable across components
- Easy to test business logic independently
- Component focuses only on presentation
- Clear separation of concerns

---

## 🏗️ Hook Structure

### Standard Hook Template

```typescript
interface UseResourceProps {
  // Configuration options
  enabled?: boolean;
  pageSize?: number;
  currentPage?: number;
  searchQuery?: string;
  filters?: Filter[];
}

export const useResource = (props?: UseResourceProps) => {
  // 1. Extract and default props
  const { enabled = true, pageSize = 10, currentPage = 1 } = props || {};

  // 2. Authorization checks (if using access control)
  const { data: canAccess } = useCan({ resource: "resource", action: "list" });
  const { data: canCreate } = useCan({ resource: "resource", action: "create" });
  const { data: canEdit } = useCan({ resource: "resource", action: "edit" });
  const { data: canDelete } = useCan({ resource: "resource", action: "delete" });

  // 3. Data fetching
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['resource', currentPage, pageSize],
    queryFn: () => fetchResource({ page: currentPage, pageSize }),
    enabled: enabled && (canAccess?.can ?? false),
  });

  // 4. Mutations
  const createMutation = useMutation({
    mutationFn: createResource,
    onSuccess: () => {
      refetch();
      toast.success('Resource created successfully');
    },
    onError: (error) => {
      toast.error('Failed to create resource', { description: error.message });
    },
  });

  const updateMutation = useMutation({
    mutationFn: updateResource,
    onSuccess: () => {
      refetch();
      toast.success('Resource updated successfully');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: deleteResource,
    onSuccess: () => {
      refetch();
      toast.success('Resource deleted successfully');
    },
  });

  // 5. Computed values
  const totalPages = Math.ceil((data?.total || 0) / pageSize);
  const hasNextPage = currentPage < totalPages;
  const hasPreviousPage = currentPage > 1;

  // 6. Exposed API
  return {
    // Permissions
    canAccess,
    canCreate,
    canEdit,
    canDelete,
    
    // Data
    itemsList: data?.items || [],
    total: data?.total || 0,
    
    // Loading states
    isLoading,
    isCreating: createMutation.isPending,
    isUpdating: updateMutation.isPending,
    isDeleting: deleteMutation.isPending,
    
    // Error states
    isError: !!error,
    error,
    
    // Actions
    createItem: createMutation.mutate,
    updateItem: updateMutation.mutate,
    deleteItem: deleteMutation.mutate,
    refetch,
    
    // Computed
    totalPages,
    hasNextPage,
    hasPreviousPage,
  };
};
```

---

## 📋 Hook Responsibilities

### 1. Data Fetching
- Query configuration (keys, functions, options)
- Pagination handling
- Filtering and sorting
- Cache management
- Error handling

### 2. Mutations
- Create, update, delete operations
- Optimistic updates
- Cache invalidation
- Success/error notifications
- Rollback on errors

### 3. State Management
- Loading states
- Error states
- Form states (if applicable)
- Selection states (if applicable)

### 4. Authorization
- Permission checks
- Access control integration
- Role-based filtering

### 5. Business Logic
- Data transformations
- Computed values
- Validation rules
- Side effects

### 6. API Exposure
- Clean, consistent interface
- Type-safe return values
- Well-documented props and returns

---

## 🔄 Component Responsibilities

### What Components Should Do

✅ **Render UI** based on hook data
✅ **Handle user interactions** (clicks, form submissions)
✅ **Display loading/error states** from hooks
✅ **Compose multiple hooks** when needed
✅ **Manage local UI state** (modals, dialogs, form fields)

### What Components Should NOT Do

❌ **Fetch data directly** (use hooks)
❌ **Call APIs directly** (use hooks)
❌ **Manage complex state** (use hooks)
❌ **Implement business logic** (use hooks)
❌ **Handle authorization** (use hooks)

---

## 🎨 Usage Patterns

### Pattern 1: Simple List Component

```typescript
export const ResourceList = () => {
  const { itemsList, isLoading, isError } = useResource();

  if (isLoading) return <Spinner />;
  if (isError) return <ErrorMessage />;

  return (
    <div>
      {itemsList.map(item => (
        <ResourceCard key={item.id} item={item} />
      ))}
    </div>
  );
};
```

### Pattern 2: List with Actions

```typescript
export const ResourceList = () => {
  const {
    itemsList,
    canCreate,
    canEdit,
    canDelete,
    createItem,
    updateItem,
    deleteItem,
    isCreating,
    isUpdating,
    isDeleting,
  } = useResource();

  const handleCreate = () => {
    createItem({ name: 'New Resource' });
  };

  const handleEdit = (id: string) => {
    updateItem({ id, name: 'Updated Resource' });
  };

  const handleDelete = (id: string) => {
    deleteItem(id);
  };

  return (
    <div>
      {canCreate?.can && (
        <Button onClick={handleCreate} disabled={isCreating}>
          Create
        </Button>
      )}
      {itemsList.map(item => (
        <ResourceCard
          key={item.id}
          item={item}
          canEdit={canEdit}
          canDelete={canDelete}
          onEdit={handleEdit}
          onDelete={handleDelete}
          isUpdating={isUpdating}
          isDeleting={isDeleting}
        />
      ))}
    </div>
  );
};
```

### Pattern 3: List with Filters and Pagination

```typescript
export const ResourceList = () => {
  const [searchQuery, setSearchQuery] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 10;

  const {
    itemsList,
    total,
    totalPages,
    isLoading,
    refetch,
  } = useResource({
    searchQuery,
    currentPage,
    pageSize,
  });

  return (
    <div>
      <SearchInput
        value={searchQuery}
        onChange={setSearchQuery}
        onSearch={() => {
          setCurrentPage(1);
          refetch();
        }}
      />
      <ResourceTable items={itemsList} isLoading={isLoading} />
      <Pagination
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={setCurrentPage}
      />
    </div>
  );
};
```

### Pattern 4: Composing Multiple Hooks

```typescript
export const ProductDetail = ({ productId }: { productId: string }) => {
  // Fetch product details
  const { data: product, isLoading: isLoadingProduct } = useProduct(productId);
  
  // Fetch related plans
  const { itemsList: plans, isLoading: isLoadingPlans } = useProductPlans({
    productId,
  });
  
  // Fetch related roles
  const { itemsList: roles, isLoading: isLoadingRoles } = useProductRoles({
    productId,
  });

  const isLoading = isLoadingProduct || isLoadingPlans || isLoadingRoles;

  if (isLoading) return <Spinner />;

  return (
    <div>
      <ProductInfo product={product} />
      <PlansList plans={plans} />
      <RolesList roles={roles} />
    </div>
  );
};
```

---

## 🧪 Testing Benefits

### Testing Hooks Independently

```typescript
// ✅ Easy to test business logic
describe('useProducts', () => {
  it('should fetch products', async () => {
    const { result } = renderHook(() => useProducts());
    
    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
    
    expect(result.current.itemsList).toHaveLength(10);
  });

  it('should create a product', async () => {
    const { result } = renderHook(() => useProducts());
    
    act(() => {
      result.current.createItem({ name: 'New Product' });
    });
    
    await waitFor(() => {
      expect(result.current.isCreating).toBe(false);
    });
    
    expect(result.current.itemsList).toContainEqual(
      expect.objectContaining({ name: 'New Product' })
    );
  });
});
```

### Testing Components with Mocked Hooks

```typescript
// ✅ Easy to test components with mocked hooks
jest.mock('./hooks/useProducts', () => ({
  useProducts: jest.fn(() => ({
    itemsList: [{ id: '1', name: 'Test Product' }],
    isLoading: false,
    isError: false,
  })),
}));

describe('ProductList', () => {
  it('should render products', () => {
    render(<ProductList />);
    expect(screen.getByText('Test Product')).toBeInTheDocument();
  });
});
```

---

## 🔄 Reusability Examples

### Same Hook, Different Components

```typescript
// Hook defined once
export const useProducts = (props?: UseProductsProps) => {
  // ... implementation
};

// Used in list page
export const ProductList = () => {
  const { itemsList, isLoading } = useProducts();
  // ... render table
};

// Used in dropdown selector
export const ProductSelector = () => {
  const { itemsList } = useProducts({ pageSize: 100 });
  // ... render dropdown
};

// Used in dashboard widget
export const ProductStats = () => {
  const { total } = useProducts();
  // ... render stat card
};
```

### Shared Logic Across Resources

```typescript
// Base hook with common logic
const useBaseResource = <T>(resource: string) => {
  // Common fetching, mutations, etc.
};

// Specific hooks extend base
export const useProducts = () => useBaseResource<Product>('products');
export const useOrganizations = () => useBaseResource<Organization>('organizations');
export const usePlans = () => useBaseResource<Plan>('plans');
```

---

## 📚 Best Practices

### 1. Consistent Hook Interface

All hooks should follow the same structure:
- Props interface with optional configuration
- Return object with consistent naming
- Similar loading/error state patterns

### 2. Type Safety

```typescript
// ✅ Strongly typed
interface Product {
  id: string;
  name: string;
  status: boolean;
}

interface UseProductsProps {
  pageSize?: number;
  currentPage?: number;
}

export const useProducts = (props?: UseProductsProps) => {
  // Implementation
  return {
    itemsList: [] as Product[],
    // ... other returns
  };
};
```

### 3. Error Handling

```typescript
export const useResource = () => {
  const { data, error } = useQuery({
    queryFn: fetchResource,
    onError: (error) => {
      // Log error
      logger.error('Failed to fetch resource', error);
      // Show user-friendly message
      toast.error('Failed to load resource');
    },
  });

  return {
    itemsList: data || [],
    isError: !!error,
    error: error?.message || 'Unknown error',
  };
};
```

### 4. Loading States

```typescript
export const useResource = () => {
  const { isLoading } = useQuery(...);
  const { isPending: isCreating } = useMutation(...);
  const { isPending: isUpdating } = useMutation(...);
  const { isPending: isDeleting } = useMutation(...);

  return {
    isLoading,
    isCreating,
    isUpdating,
    isDeleting,
    // Combined loading state
    isProcessing: isLoading || isCreating || isUpdating || isDeleting,
  };
};
```

### 5. Cache Management

```typescript
export const useResource = () => {
  const queryClient = useQueryClient();
  
  const createMutation = useMutation({
    mutationFn: createResource,
    onSuccess: () => {
      // Invalidate related queries
      queryClient.invalidateQueries({ queryKey: ['resources'] });
      queryClient.invalidateQueries({ queryKey: ['resource-stats'] });
    },
  });

  return { createItem: createMutation.mutate };
};
```

### 6. Documentation

```typescript
/**
 * Custom hook for managing products
 * 
 * @param props - Configuration options
 * @param props.pageSize - Number of items per page (default: 10)
 * @param props.currentPage - Current page number (default: 1)
 * @param props.searchQuery - Search query string (default: "")
 * 
 * @returns Object containing products data, loading states, and actions
 * 
 * @example
 * ```tsx
 * const { itemsList, isLoading, createItem } = useProducts({
 *   pageSize: 20,
 *   currentPage: 1,
 * });
 * ```
 */
export const useProducts = (props?: UseProductsProps) => {
  // Implementation
};
```

---

## 🚫 Anti-Patterns to Avoid

### ❌ Don't Mix Concerns

```typescript
// ❌ Bad: Business logic in component
export const ProductList = () => {
  const [products, setProducts] = useState([]);
  
  useEffect(() => {
    fetch('/api/products').then(res => res.json()).then(setProducts);
  }, []);
  
  // ... rest of component
};
```

### ❌ Don't Duplicate Logic

```typescript
// ❌ Bad: Same logic in multiple components
export const ProductList = () => {
  const { data } = useQuery({ queryFn: fetchProducts });
  // ...
};

export const ProductSelector = () => {
  const { data } = useQuery({ queryFn: fetchProducts }); // Duplicated!
  // ...
};
```

### ❌ Don't Expose Implementation Details

```typescript
// ❌ Bad: Exposing internal query object
export const useProducts = () => {
  const query = useQuery(...);
  return { query }; // Component shouldn't know about query
};

// ✅ Good: Exposing only what's needed
export const useProducts = () => {
  const query = useQuery(...);
  return {
    itemsList: query.data || [],
    isLoading: query.isLoading,
    refetch: query.refetch,
  };
};
```

---

## 📊 Comparison: Before vs After

| Aspect | Direct Implementation | Custom Hooks Pattern |
|--------|----------------------|---------------------|
| **Reusability** | ❌ Logic tied to component | ✅ Reusable across components |
| **Testability** | ❌ Hard to test UI + logic | ✅ Easy to test logic separately |
| **Maintainability** | ❌ Changes affect component | ✅ Changes isolated to hook |
| **Readability** | ❌ Mixed concerns | ✅ Clear separation |
| **Type Safety** | ⚠️ Varies | ✅ Consistent typing |
| **Code Size** | ❌ Larger components | ✅ Smaller, focused components |

---

## 🎯 Summary

The **Custom Hooks Pattern** provides:

1. **Separation of Concerns**: Business logic separated from presentation
2. **Reusability**: Logic can be shared across multiple components
3. **Testability**: Easy to test business logic independently
4. **Maintainability**: Changes are isolated and easier to manage
5. **Consistency**: Standardized patterns across the application
6. **Type Safety**: Strong typing throughout the application

By following this pattern, you create a codebase that is:
- Easier to understand
- Easier to test
- Easier to maintain
- Easier to extend

---

## 📚 Related Documentation

- [Granular Authorization](./GRANULAR_AUTHORIZATION.md) - How authorization is integrated into hooks
- [Auth Request Optimization](./AUTH_REQUEST_OPTIMIZATION.md) - Performance considerations in hooks

---

**Last updated:** 2025-01-XX
**Version:** 1.0
