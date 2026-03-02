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

  // Get orgId from various sources
  // IMPORTANT: RLS uses get_my_org_id() which reads from JWT app_metadata.org_id
  // So we should prioritize orgIdFromJWT to ensure RLS allows the query
  const orgIdFromJWT = session ? getOrganizationId(parseJWT(session.access_token)) : null;
  // Use JWT org_id first (for RLS compatibility), then fallback to explicit orgId or config
  const orgId = orgIdFromJWT || organizationId || config.organizationId;

  const fetchSubscription = useCallback(async () => {
    if (!orgId) {
      logger.debug('No organization ID available', { 
        organizationId,
        configOrgId: config.organizationId,
        jwtOrgId: orgIdFromJWT,
        hasSession: !!session
      });
      setSubscription(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Warn if explicit orgId doesn't match JWT org_id (RLS will block)
      if (organizationId && orgIdFromJWT && organizationId !== orgIdFromJWT) {
        logger.warn('Organization ID mismatch - RLS may block access', {
          explicitOrgId: organizationId,
          jwtOrgId: orgIdFromJWT,
          usingOrgId: orgId
        });
      }

      logger.debug('Fetching current subscription', { 
        organizationId: orgId,
        orgIdFromJWT,
        explicitOrgId: organizationId,
        orgIdMatches: orgId === orgIdFromJWT,
        hasSession: !!session,
        sessionUserId: session?.user?.id 
      });

      // Fetch subscription with organization and product
      // Note: RLS will filter by get_my_org_id() from JWT, so we still filter by orgId
      // for efficiency, but RLS must allow it
      // Filter for active subscriptions or valid (non-expired) trial subscriptions
      // We'll filter expired trials in the application logic after fetching
      const { data: subscriptionData, error: fetchError } = await supabase
        .from('org_product_subscriptions')
        .select('*, organization:organizations(*), product:products(*)')
        .eq('org_id', orgId)
        .in('status', ['active', 'trial'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      logger.debug('Subscription query result', { 
        hasData: !!subscriptionData,
        error: fetchError,
        errorCode: fetchError?.code,
        errorMessage: fetchError?.message,
        errorDetails: fetchError?.details,
        errorHint: fetchError?.hint
      });

      if (fetchError) {
        // Log detailed error information
        logger.error('Error fetching subscription', {
          code: fetchError.code,
          message: fetchError.message,
          details: fetchError.details,
          hint: fetchError.hint
        });
        throw new Error(fetchError.message);
      }

      // Filter out expired trial subscriptions
      let validSubscriptionData = subscriptionData;
      if (subscriptionData && subscriptionData.status === 'trial') {
        const now = new Date();
        const trialEndsAt = subscriptionData.trial_ends_at ? new Date(subscriptionData.trial_ends_at) : null;
        
        // If trial has ended, treat as no subscription
        if (trialEndsAt && trialEndsAt <= now) {
          logger.debug('Trial subscription has expired', {
            trialEndsAt: subscriptionData.trial_ends_at,
            now: now.toISOString()
          });
          validSubscriptionData = null;
        }
      }

      // If subscription exists, fetch the product_plan and plan separately
      let productPlan = null;
      let plan = null;
      if (validSubscriptionData) {
        // Fetch product_plan with plan join
        const { data: productPlanData, error: productPlanError } = await supabase
          .from('product_plans')
          .select('*, plan:plans(*)')
          .eq('product_id', validSubscriptionData.product_id)
          .eq('plan_id', validSubscriptionData.plan_id)
          .is('deleted_at', null)
          .maybeSingle();

        if (productPlanError) {
          logger.warn('Error fetching product_plan', productPlanError);
        } else {
          productPlan = productPlanData;
          plan = productPlanData?.plan || null;
        }

        // If plan not found via product_plan, fetch it directly
        if (!plan && validSubscriptionData.plan_id) {
          const { data: planData, error: planError } = await supabase
            .from('plans')
            .select('*')
            .eq('id', validSubscriptionData.plan_id)
            .is('deleted_at', null)
            .maybeSingle();

          if (!planError && planData) {
            plan = planData;
          }
        }
      }

      // Combine subscription data with product_plan and plan
      const data = validSubscriptionData 
        ? { 
            ...validSubscriptionData, 
            product_plan: productPlan ? { ...productPlan, plan } : null 
          } 
        : null;

      setSubscription(data as Subscription | null);
      logger.info('Current subscription fetched successfully', { 
        hasSubscription: !!data,
        hasProductPlan: !!productPlan 
      });
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
