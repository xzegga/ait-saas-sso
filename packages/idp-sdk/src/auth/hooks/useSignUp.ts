/**
 * Hook for user signup with organization creation
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { AuthenticationError, ValidationError } from '../../shared/errors';
import { isValidEmail } from '../../shared/utils';

export interface SignUpParams {
  email: string;
  password: string;
  fullName: string;
  productId: string;
  planId: string;
  billingInterval?: string; // Billing interval key (e.g., 'month', 'year')
  orgName?: string;
  useUserName: boolean;
}

export interface SignUpResult {
  userId: string;
  orgId: string;
  subscriptionId: string;
  status: 'trial' | 'active';
  trialDays?: number;
  trialEndsAt?: string;
}

export interface UseSignUpReturn {
  signUp: (params: SignUpParams) => Promise<SignUpResult>;
  loading: boolean;
  error: Error | null;
}

export const useSignUp = (): UseSignUpReturn => {
  const { supabase, config } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const signUp = useCallback(
    async (params: SignUpParams): Promise<SignUpResult> => {
      setLoading(true);
      setError(null);

      try {
        // Validate email
        if (!params.email || !isValidEmail(params.email)) {
          throw new ValidationError('Invalid email address');
        }

        // Validate password
        if (!params.password || params.password.length < 6) {
          throw new ValidationError('Password must be at least 6 characters');
        }

        // Validate full name
        if (!params.fullName || params.fullName.trim().length === 0) {
          throw new ValidationError('Full name is required');
        }

        // Validate product ID
        if (!params.productId) {
          throw new ValidationError('Product ID is required');
        }

        // Validate plan ID
        if (!params.planId) {
          throw new ValidationError('Plan ID is required');
        }

        logger.debug('Attempting signup', { email: params.email, productId: params.productId });

        // 1. Create user in Supabase Auth
        const { data: authData, error: authError } = await supabase.auth.signUp({
          email: params.email,
          password: params.password,
          options: {
            data: {
              full_name: params.fullName,
            },
          },
        });

        if (authError) {
          throw new AuthenticationError(authError.message);
        }

        if (!authData.user) {
          throw new AuthenticationError('User creation failed');
        }

        logger.debug('User created in Auth', { userId: authData.user.id });

        // Wait a bit for the trigger to create the profile
        await new Promise((resolve) => setTimeout(resolve, 500));

        // 2. Call the complete signup function
        const { data: signupData, error: signupError } = await supabase.rpc(
          'fn_complete_user_signup',
          {
            p_user_id: authData.user.id,
            p_product_id: params.productId,
            p_plan_id: params.planId,
            p_billing_interval: params.billingInterval || 'month',
            p_org_name: params.orgName || null,
            p_use_user_name: params.useUserName,
          }
        );

        if (signupError) {
          logger.error('Signup RPC error', signupError);
          throw new AuthenticationError(signupError.message || 'Signup failed');
        }

        if (!signupData?.success) {
          const errorMsg = signupData?.error || 'Signup failed';
          logger.error('Signup failed', { error: errorMsg, data: signupData });
          throw new AuthenticationError(errorMsg);
        }

        logger.info('Signup completed successfully', {
          userId: authData.user.id,
          orgId: signupData.org_id,
          subscriptionId: signupData.subscription_id,
          status: signupData.status,
        });

        return {
          userId: authData.user.id,
          orgId: signupData.org_id,
          subscriptionId: signupData.subscription_id,
          status: signupData.status,
          trialDays: signupData.trial_days,
          trialEndsAt: signupData.trial_ends_at,
        };
      } catch (err: any) {
        logger.error('Signup error', err);
        const error = err instanceof Error ? err : new AuthenticationError(err?.message || 'Signup failed');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  return { signUp, loading, error };
};
