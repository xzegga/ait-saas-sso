/**
 * Hook for verifying OTP codes
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { AuthenticationError } from '../../shared/errors';
import { useSendWelcomeEmail } from './useSendWelcomeEmail';

export interface UseVerifyOtpReturn {
  verifyOtp: (email: string, code: string, type: 'signup' | 'email' | 'recovery', productId?: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useVerifyOtp = (): UseVerifyOtpReturn => {
  const { supabase, config } = useIDP();
  const { sendWelcomeEmail } = useSendWelcomeEmail();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const verifyOtp = useCallback(
    async (email: string, code: string, type: 'signup' | 'email' | 'recovery', productId?: string): Promise<void> => {
      setLoading(true);
      setError(null);

      try {
        logger.debug('Verifying OTP', { email, type, codeLength: code.length });

        // Use verifyOtp with token
        // According to Supabase docs, for email OTP we use the 'token' parameter with the code
        // The code is the 6-digit OTP sent via email
        const { data, error: verifyError } = await supabase.auth.verifyOtp({
          email,
          token: code, // OTP code from email
          type,
        });

        if (verifyError) {
          logger.error('OTP verification error', verifyError);
          throw new AuthenticationError(verifyError.message || 'Invalid verification code');
        }

        if (!data.user) {
          throw new AuthenticationError('Verification failed: No user session created');
        }

        logger.info('OTP verified successfully', { userId: data.user.id, email });

        // Send welcome email after OTP verification (ALWAYS for signup, regardless of subscription)
        // This MUST execute immediately after OTP verification
        if (type === 'signup' && data.user) {
          const finalProductId = productId || config.productId;
          const userId = data.user.id;
          const userEmail = data.user.email;
          
          logger.info('OTP verified for signup, sending welcome email', { 
            userId, 
            email: userEmail,
            productId: finalProductId,
            hasProductId: !!finalProductId,
            type: 'signup'
          });
          
          if (!finalProductId) {
            logger.error('Cannot send welcome email - no productId available', {
              productId,
              configProductId: config.productId,
              userId,
            });
          } else {
            // Send welcome email - await to ensure it completes
            try {
              await sendWelcomeEmail(userId, finalProductId);
              logger.info('Welcome email sent successfully after OTP verification', {
                userId,
                productId: finalProductId,
              });
            } catch (emailErr) {
              logger.error('Failed to send welcome email after OTP verification', {
                error: emailErr,
                userId,
                productId: finalProductId,
                errorMessage: emailErr instanceof Error ? emailErr.message : String(emailErr),
                errorStack: emailErr instanceof Error ? emailErr.stack : undefined,
              });
              // Don't throw - welcome email is non-critical
            }
          }
        } else {
          logger.debug('Skipping welcome email', {
            type,
            hasUser: !!data.user,
            isSignup: type === 'signup',
          });
        }
      } catch (err) {
        const error = err instanceof Error ? err : new AuthenticationError('Verification failed');
        setError(error);
        logger.error('OTP verification error', err);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase, config, sendWelcomeEmail]
  );

  return { verifyOtp, loading, error };
};
