/**
 * Hook for password reset
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { ValidationError } from '../../shared/errors';
import { useSendPasswordResetSuccessEmail } from './useSendPasswordResetSuccessEmail';

export interface UseResetPasswordReturn {
  resetPassword: (newPassword: string, confirmPassword: string, productId?: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useResetPassword = (): UseResetPasswordReturn => {
  const { supabase, config } = useIDP();
  const { sendSuccessEmail } = useSendPasswordResetSuccessEmail();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const resetPassword = useCallback(
    async (newPassword: string, confirmPassword: string, productId?: string) => {
      setLoading(true);
      setError(null);

      try {
        // Validate password
        if (!newPassword || newPassword.length < 6) {
          throw new ValidationError('Password must be at least 6 characters');
        }

        // Validate password confirmation
        if (newPassword !== confirmPassword) {
          throw new ValidationError('Passwords do not match');
        }

        logger.debug('Resetting password');

        // Get user email before resetting
        const { data: { user } } = await supabase.auth.getUser();
        const userEmail = user?.email;

        const { error: resetError } = await supabase.auth.updateUser({
          password: newPassword,
        });

        if (resetError) {
          throw new Error(resetError.message);
        }

        logger.info('Password reset successful');

        // Send success email
        if (userEmail) {
          try {
            const finalProductId = productId || config.productId;
            await sendSuccessEmail(userEmail, finalProductId);
          } catch (emailErr) {
            logger.error('Failed to send password reset success email', emailErr);
            // Don't throw - success email is non-critical
          }
        }
      } catch (err: any) {
        logger.error('Password reset failed', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Password reset failed');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase, config, sendSuccessEmail]
  );

  return { resetPassword, loading, error };
};
