/**
 * Hook for user signup (creates user only, no org/subscription)
 * Uses OTP-based email verification flow
 * After verification, use useCompleteSignup to create org/subscription
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { AuthenticationError, ValidationError } from '../../shared/errors';
import { isValidEmail } from '../../shared/utils';

export interface SignUpParams {
  email: string;
  password: string;
  confirmPassword: string;
  fullName: string;
  orgName?: string;
  useUserName: boolean;
}

export interface SignUpResult {
  userId: string;
  email: string;
  // Note: User is not yet verified, so we don't return orgId/subscriptionId yet
  // These will be available after OTP verification and plan selection
}

export interface UseSignUpReturn {
  signUp: (params: SignUpParams) => Promise<SignUpResult>;
  loading: boolean;
  error: Error | null;
}

export const useSignUp = (): UseSignUpReturn => {
  const { supabase } = useIDP();
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

        // Validate password confirmation
        if (params.password !== params.confirmPassword) {
          throw new ValidationError('Passwords do not match');
        }

        // Validate full name
        if (!params.fullName || params.fullName.trim().length === 0) {
          throw new ValidationError('Full name is required');
        }

        logger.debug('Attempting signup', { email: params.email });

        // Create user in Supabase Auth with OTP
        // Supabase will automatically send OTP email when signUp is called (if SMTP is enabled)
        const siteUrl = typeof window !== 'undefined' ? window.location.origin : 'http://localhost:3000';
        const { data: authData, error: authError } = await supabase.auth.signUp({
          email: params.email,
          password: params.password,
          options: {
            data: {
              full_name: params.fullName,
              org_name: params.orgName,
              use_user_name: params.useUserName,
            },
            emailRedirectTo: `${siteUrl}/auth/callback`,
          },
        });

        if (authError) {
          logger.error('Auth signup error', authError);
          throw new AuthenticationError(authError.message);
        }

        if (!authData.user) {
          throw new AuthenticationError('User creation failed');
        }

        logger.debug('User created in Auth', { userId: authData.user.id });

        // Wait a bit for the trigger to create the profile
        await new Promise((resolve) => setTimeout(resolve, 500));

        // Note: We don't create org/subscription here
        // That will be done after email verification using useCompleteSignup

        return {
          userId: authData.user.id,
          email: params.email,
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
