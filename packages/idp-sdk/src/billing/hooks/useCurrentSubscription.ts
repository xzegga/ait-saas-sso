/**
 * Hook for fetching current subscription
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import type { Subscription } from '../../shared/types';
import { parseJWT, getOrganizationId } from '../../shared/utils';
import { useAuth } from '../../providers/AuthProvider';

export interface UseCurrentSubscriptionReturn {
  subscription: Subscription | null;
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export const useCurrentSubscription = (organizationId?: string): UseCurrentSubscriptionReturn => {
  const { supabase, config } = useIDP();
  const { session } = useAuth();
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const orgId = organizationId || config.organizationId || (session ? getOrganizationId(parseJWT(session.access_token)) : null);

  const fetchSubscription = useCallback(async () => {
    if (!orgId) {
      setSubscription(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching current subscription', { organizationId: orgId });

      const { data, error: fetchError } = await supabase
        .from('org_product_subscriptions')
        .select('*, organization:organizations(*), product:products(*), product_plan:product_plans(*)')
        .eq('org_id', orgId)
        .eq('status', 'active')
        .is('deleted_at', null)
        .single();

      if (fetchError && fetchError.code !== 'PGRST116') {
        throw new Error(fetchError.message);
      }

      setSubscription(data as Subscription | null);
      logger.info('Current subscription fetched successfully');
    } catch (err: any) {
      logger.error('Error fetching subscription', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch subscription');
      setError(error);
    } finally {
      setLoading(false);
    }
  }, [supabase, orgId]);

  useEffect(() => {
    fetchSubscription();
  }, [fetchSubscription]);

  return {
    subscription,
    loading,
    error,
    refetch: fetchSubscription,
  };
};
