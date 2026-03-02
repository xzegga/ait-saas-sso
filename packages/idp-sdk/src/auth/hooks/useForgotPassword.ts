/**
 * Hook for password recovery (forgot password)
 * Uses OTP-based verification flow
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { ValidationError } from '../../shared/errors';
import { isValidEmail } from '../../shared/utils';

export interface UseForgotPasswordReturn {
  sendResetEmail: (email: string) => Promise<void>;
  resendCode: (email: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
  success: boolean;
}

export const useForgotPassword = (): UseForgotPasswordReturn => {
  const { supabase, config } = useIDP();
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

        logger.debug('Sending password reset OTP', { email });

        // Use Supabase's resetPasswordForEmail which sends OTP
        // Supabase will automatically send OTP email
        const redirectTo = typeof window !== 'undefined' 
          ? `${window.location.origin}/reset-password`
          : 'http://localhost:3000/reset-password';
        
        const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo,
        });

        if (resetError) {
          logger.error('Password reset OTP error', resetError);
          throw new Error(resetError.message);
        }

        // Note: Supabase sends the OTP email automatically
        // We could customize it via Edge Function trigger, but for now we rely on Supabase's default
        // TODO: Implement custom OTP email via Edge Function trigger

        logger.info('Password reset OTP sent', { email });
        setSuccess(true);
      } catch (err: any) {
        logger.error('Failed to send password reset OTP', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to send reset email');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  const resendCode = useCallback(
    async (email: string) => {
      setLoading(true);
      setError(null);

      try {
        if (!email || !isValidEmail(email)) {
          throw new ValidationError('Invalid email address');
        }

        logger.debug('Resending password reset OTP', { email });

        const redirectTo = typeof window !== 'undefined' 
          ? `${window.location.origin}/reset-password`
          : 'http://localhost:3000/reset-password';

        // For password reset, we need to call resetPasswordForEmail again
        // Supabase doesn't support 'recovery' type for resend, only 'signup' or 'email_change'
        const { error: resendError } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo,
        });

        if (resendError) {
          throw new Error(resendError.message);
        }

        logger.info('Password reset OTP resent', { email });
      } catch (err: any) {
        logger.error('Failed to resend password reset OTP', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to resend code');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase]
  );

  return { sendResetEmail, resendCode, loading, error, success };
};
