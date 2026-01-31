/**
 * Hook for email/password login
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { AuthenticationError, ValidationError } from '../../shared/errors';
import { isValidEmail } from '../../shared/utils';

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface UseLoginReturn {
  login: (credentials: LoginCredentials) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useLogin = (): UseLoginReturn => {
  const { supabase } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const login = useCallback(
    async (credentials: LoginCredentials) => {
      setLoading(true);
      setError(null);

      try {
        // Validate email
        if (!credentials.email || !isValidEmail(credentials.email)) {
          throw new ValidationError('Invalid email address');
        }

        // Validate password
        if (!credentials.password || credentials.password.length < 6) {
          throw new ValidationError('Password must be at least 6 characters');
        }

        logger.debug('Attempting login', { email: credentials.email });

        const { data, error: authError } = await supabase.auth.signInWithPassword({
          email: credentials.email,
          password: credentials.password,
        });

        if (authError) {
          throw new AuthenticationError(authError.message);
        }

        if (!data.session) {
          throw new AuthenticationError('No session returned');
        }

        logger.info('Login successful', { userId: data.user?.id });
      } catch (err: any) {
        logger.error('Login failed', err);
        const error = err instanceof Error ? err : new AuthenticationError(err?.message || 'Login failed');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  return { login, loading, error };
};
