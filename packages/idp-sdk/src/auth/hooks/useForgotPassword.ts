/**
 * Hook for password recovery (forgot password)
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { ValidationError } from '../../shared/errors';
import { isValidEmail } from '../../shared/utils';

export interface UseForgotPasswordReturn {
  sendResetEmail: (email: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
  success: boolean;
}

export const useForgotPassword = (): UseForgotPasswordReturn => {
  const { supabase } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [success, setSuccess] = useState(false);

  const sendResetEmail = useCallback(
    async (email: string) => {
      setLoading(true);
      setError(null);
      setSuccess(false);

      try {
        // Validate email
        if (!email || !isValidEmail(email)) {
          throw new ValidationError('Invalid email address');
        }

        logger.debug('Sending password reset email', { email });

        const redirectTo = typeof window !== 'undefined' 
          ? `${window.location.origin}/reset-password`
          : undefined;
        
        const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo,
        });

        if (resetError) {
          throw new Error(resetError.message);
        }

        logger.info('Password reset email sent', { email });
        setSuccess(true);
      } catch (err: any) {
        logger.error('Failed to send password reset email', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to send reset email');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  return { sendResetEmail, loading, error, success };
};
