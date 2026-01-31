/**
 * Hook for password reset
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { ValidationError } from '../../shared/errors';

export interface UseResetPasswordReturn {
  resetPassword: (newPassword: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useResetPassword = (): UseResetPasswordReturn => {
  const { supabase } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const resetPassword = useCallback(
    async (newPassword: string) => {
      setLoading(true);
      setError(null);

      try {
        // Validate password
        if (!newPassword || newPassword.length < 6) {
          throw new ValidationError('Password must be at least 6 characters');
        }

        logger.debug('Resetting password');

        const { error: resetError } = await supabase.auth.updateUser({
          password: newPassword,
        });

        if (resetError) {
          throw new Error(resetError.message);
        }

        logger.info('Password reset successful');
      } catch (err: any) {
        logger.error('Password reset failed', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Password reset failed');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  return { resetPassword, loading, error };
};
