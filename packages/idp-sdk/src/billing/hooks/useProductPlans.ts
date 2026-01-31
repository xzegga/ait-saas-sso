/**
 * Hook for fetching product plans
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import type { ProductPlan } from '../../shared/types';

export interface UseProductPlansReturn {
  plans: ProductPlan[];
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export const useProductPlans = (productId: string): UseProductPlansReturn => {
  const { supabase } = useIDP();
  const [plans, setPlans] = useState<ProductPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchPlans = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching product plans', { productId });

      const { data, error: fetchError } = await supabase
        .from('product_plans')
        .select('*, plan:plans(*), prices_by_interval:product_plan_prices(*)')
        .eq('product_id', productId)
        .eq('status', true)
        .is('deleted_at', null);

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      setPlans((data || []) as ProductPlan[]);
      logger.info('Product plans fetched successfully');
    } catch (err: any) {
      logger.error('Error fetching product plans', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch plans');
      setError(error);
    } finally {
      setLoading(false);
    }
  }, [supabase, productId]);

  useEffect(() => {
    fetchPlans();
  }, [fetchPlans]);

  return {
    plans,
    loading,
    error,
    refetch: fetchPlans,
  };
};
