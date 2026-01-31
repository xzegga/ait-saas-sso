/**
 * Hook for fetching available plans for signup
 * Returns simplified plan information for plan selection during registration
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface PlanPrice {
  billing_interval: string;
  billing_interval_label: string;
  price: number;
  currency: string;
  is_default: boolean;
}

export interface PlanEntitlement {
  key: string;
  description?: string;
  value_text?: string;
  data_type: string;
}

export interface AvailablePlan {
  id: string;
  name: string;
  description?: string;
  prices: PlanPrice[];
  is_trial_eligible?: boolean;
  entitlements: PlanEntitlement[];
  product_plan_id: string;
}

export interface UseAvailablePlansReturn {
  plans: AvailablePlan[];
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export const useAvailablePlans = (productId?: string): UseAvailablePlansReturn => {
  const { supabase, config } = useIDP();
  const [plans, setPlans] = useState<AvailablePlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const targetProductId = productId || config.productId;

  const fetchPlans = useCallback(async () => {
    if (!targetProductId) {
      setPlans([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching available plans for signup', { productId: targetProductId });

      // Check if targetProductId is a UUID or client_id (slug)
      const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetProductId);

      logger.debug('Product ID type detection', { 
        productId: targetProductId, 
        isUUID,
        length: targetProductId.length 
      });

      // Get product trial_days to determine if plans are trial eligible
      // Handle both UUID and client_id
      // Note: We don't filter by status here because we want to allow signup even if product is inactive
      // The product just needs to exist and not be deleted
      let productQuery;
      if (isUUID) {
        productQuery = supabase
          .from('products')
          .select('id, trial_days, status')
          .eq('id', targetProductId)
          .is('deleted_at', null);
      } else {
        productQuery = supabase
          .from('products')
          .select('id, trial_days, status')
          .eq('client_id', targetProductId)
          .is('deleted_at', null);
      }

      const { data: productData, error: productError } = await productQuery.maybeSingle();

      if (productError) {
        logger.error('Product query error', { 
          error: productError, 
          productId: targetProductId, 
          isUUID,
          code: productError.code,
          message: productError.message,
          details: productError.details,
          hint: productError.hint
        });
        throw new Error(`Failed to fetch product: ${productError.message}`);
      }

      if (!productData) {
        logger.error('Product not found', { 
          productId: targetProductId, 
          isUUID 
        });
        throw new Error(`Product not found: ${targetProductId}`);
      }

      logger.debug('Product found', { 
        productId: productData.id, 
        trialDays: productData.trial_days,
        status: productData.status 
      });

      // Get the actual product UUID (in case we queried by client_id)
      const actualProductId = productData.id;
      const trialDays = productData?.trial_days;
      const isTrialEligible = trialDays !== null && trialDays !== undefined && trialDays > 0;

      // Get available plans for the product with prices and entitlements
      // Only active plans (is_public can be true in product_plans OR in plans table)
      logger.debug('Fetching product_plans with prices and entitlements', { productId: actualProductId });
      
      const { data, error: fetchError } = await supabase
        .from('product_plans')
        .select(`
          id,
          plan_id,
          is_public,
          status,
          plan:plans!inner(
            id,
            name,
            description,
            is_public,
            status
          )
        `)
        .eq('product_id', actualProductId)
        .eq('status', true)
        .is('deleted_at', null);

      if (fetchError) {
        logger.error('Product plans query error', { 
          error: fetchError, 
          productId: actualProductId,
          code: fetchError.code,
          message: fetchError.message,
          details: fetchError.details,
          hint: fetchError.hint
        });
        throw new Error(`Failed to fetch plans: ${fetchError.message}`);
      }

      logger.debug('Product plans fetched', { 
        count: data?.length || 0,
        plans: data?.map((pp: any) => ({
          id: pp.plan?.id,
          name: pp.plan?.name,
          is_public: pp.is_public,
          plan_is_public: pp.plan?.is_public,
          status: pp.status,
          plan_status: pp.plan?.status
        }))
      });

      // Filter public plans
      const publicPlans = (data || []).filter((pp: any) => {
        // Ensure plan exists and is active
        if (!pp.plan || !pp.plan.status) {
          return false;
        }
        
        // Check if plan is public:
        // - If product_plans.is_public is explicitly true, it's public
        // - If product_plans.is_public is false/null, check plans.is_public
        const isPublic = pp.is_public === true || (pp.is_public !== false && pp.plan.is_public === true);
        
        return isPublic;
      });

      // Fetch prices and entitlements for each plan
      logger.debug('Processing plans with details', { 
        count: publicPlans.length,
        plans: publicPlans.map((pp: any) => ({
          product_plan_id: pp.id,
          plan_id: pp.plan?.id,
          plan_name: pp.plan?.name,
          product_plan_status: pp.status,
          product_plan_is_public: pp.is_public,
          plan_status: pp.plan?.status,
          plan_is_public: pp.plan?.is_public
        }))
      });

      const plansWithDetails = await Promise.all(
        publicPlans.map(async (pp: any) => {
          const planId = pp.plan.id;
          const productPlanId = pp.id;
          
          logger.debug('Processing plan', { 
            planId, 
            productPlanId,
            product_plan_status: pp.status,
            product_plan_is_public: pp.is_public,
            plan_status: pp.plan?.status,
            plan_is_public: pp.plan?.is_public
          });

          // Fetch prices for this product_plan
          logger.debug('Fetching prices for product_plan', { productPlanId, planId });
          const { data: pricesData, error: pricesError } = await supabase
            .from('product_plan_prices')
            .select(`
              billing_interval,
              price,
              currency,
              is_default,
              billing_interval_details:billing_intervals!product_plan_prices_billing_interval_fkey(
                key,
                label,
                sort_order
              )
            `)
            .eq('product_plan_id', productPlanId)
            .order('is_default', { ascending: false });

          if (pricesError) {
            logger.error('Error fetching prices for plan', { 
              productPlanId, 
              planId, 
              error: pricesError,
              code: pricesError.code,
              message: pricesError.message,
              details: pricesError.details,
              hint: pricesError.hint
            });
          } else {
            logger.debug('Prices fetched for product_plan', { 
              productPlanId, 
              planId,
              count: pricesData?.length || 0,
              prices: pricesData?.map((p: any) => ({
                billing_interval: p.billing_interval,
                price: p.price,
                currency: p.currency,
                is_default: p.is_default
              }))
            });
          }

          // Sort prices by sort_order in client (PostgREST can't order by nested fields)
          const sortedPricesData = (pricesData || []).sort((a: any, b: any) => {
            // First sort by is_default (default first)
            if (a.is_default !== b.is_default) {
              return a.is_default ? -1 : 1;
            }
            // Then sort by sort_order
            const aSortOrder = a.billing_interval_details?.sort_order ?? 999;
            const bSortOrder = b.billing_interval_details?.sort_order ?? 999;
            return aSortOrder - bSortOrder;
          });

          // Fetch entitlements for this plan
          logger.debug('Fetching entitlements for plan', { planId, productPlanId });
          const { data: entitlementsData, error: entitlementsError } = await supabase
            .from('plan_entitlements')
            .select(`
              value_text,
              entitlement:entitlements!plan_entitlements_entitlement_id_fkey(
                key,
                description,
                data_type
              )
            `)
            .eq('plan_id', planId);

          if (entitlementsError) {
            logger.error('Error fetching entitlements for plan', { 
              planId, 
              error: entitlementsError,
              code: entitlementsError.code,
              message: entitlementsError.message,
              details: entitlementsError.details,
              hint: entitlementsError.hint
            });
          } else {
            logger.debug('Entitlements fetched for plan', { 
              planId, 
              count: entitlementsData?.length || 0,
              entitlements: entitlementsData?.map((e: any) => ({
                key: e.entitlement?.key,
                value: e.value_text,
                data_type: e.entitlement?.data_type
              }))
            });
          }

          // Map prices
          const prices: PlanPrice[] = sortedPricesData.map((p: any) => ({
            billing_interval: p.billing_interval,
            billing_interval_label: p.billing_interval_details?.label || p.billing_interval,
            price: Number(p.price),
            currency: p.currency || 'USD',
            is_default: p.is_default || false,
          }));

          // Map entitlements
          const entitlements: PlanEntitlement[] = (entitlementsData || []).map((e: any) => ({
            key: e.entitlement?.key || '',
            description: e.entitlement?.description || undefined,
            value_text: e.value_text || undefined,
            data_type: e.entitlement?.data_type || 'text',
          }));

          return {
            id: planId,
            name: pp.plan.name || 'Unnamed Plan',
            description: pp.plan.description || undefined,
            prices,
            is_trial_eligible: isTrialEligible,
            entitlements,
            product_plan_id: productPlanId,
          };
        })
      );

      setPlans(plansWithDetails);
      logger.info('Available plans fetched successfully', { count: plansWithDetails.length });
    } catch (err: any) {
      logger.error('Error fetching available plans', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch plans');
      setError(error);
      setPlans([]);
    } finally {
      setLoading(false);
    }
  }, [supabase, targetProductId]);

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
