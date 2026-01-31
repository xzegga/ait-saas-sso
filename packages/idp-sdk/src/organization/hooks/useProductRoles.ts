/**
 * Hook for fetching product roles
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface ProductRole {
  id: string;
  product_id: string;
  role_name: string;
  description: string | null;
}

export interface UseProductRolesReturn {
  roles: ProductRole[];
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export const useProductRoles = (productId?: string): UseProductRolesReturn => {
  const { supabase } = useIDP();
  const [roles, setRoles] = useState<ProductRole[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchRoles = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching product roles', { productId });

      let query = supabase
        .from('product_role_definitions')
        .select('*');

      if (productId) {
        query = query.eq('product_id', productId);
      }

      const { data, error: fetchError } = await query;

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      setRoles((data || []) as ProductRole[]);
      logger.info('Product roles fetched successfully');
    } catch (err: any) {
      logger.error('Error fetching product roles', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch roles');
      setError(error);
    } finally {
      setLoading(false);
    }
  }, [supabase, productId]);

  useEffect(() => {
    fetchRoles();
  }, [fetchRoles]);

  return {
    roles,
    loading,
    error,
    refetch: fetchRoles,
  };
};
