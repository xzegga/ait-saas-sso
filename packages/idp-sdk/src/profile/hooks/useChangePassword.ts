/**
 * Hook for changing user password
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { ValidationError } from '../../shared/errors';

export interface UseChangePasswordReturn {
  changePassword: (newPassword: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useChangePassword = (): UseChangePasswordReturn => {
  const { supabase } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const changePassword = useCallback(
    async (newPassword: string) => {
      setLoading(true);
      setError(null);

      try {
        // Validate password
        if (!newPassword || newPassword.length < 6) {
          throw new ValidationError('Password must be at least 6 characters');
        }

        logger.debug('Changing password');

        const { error: updateError } = await supabase.auth.updateUser({
          password: newPassword,
        });

        if (updateError) {
          throw new Error(updateError.message);
        }

        logger.info('Password changed successfully');
      } catch (err: any) {
        logger.error('Error changing password', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to change password');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  return { changePassword, loading, error };
};
