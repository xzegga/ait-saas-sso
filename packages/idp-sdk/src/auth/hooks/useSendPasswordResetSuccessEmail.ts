/**
 * Hook for sending password reset success email
 */

import { useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface UseSendPasswordResetSuccessEmailReturn {
  sendSuccessEmail: (email: string, productId?: string) => Promise<void>;
}

export const useSendPasswordResetSuccessEmail = (): UseSendPasswordResetSuccessEmailReturn => {
  const { supabase, config } = useIDP();

  const sendSuccessEmail = useCallback(
    async (email: string, productId?: string) => {
      try {
        logger.debug('Sending password reset success email', { email, productId });

        // Get product UUID if productId is provided
        let productUuid: string | null = null;
        if (productId) {
          if (productId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
            productUuid = productId;
          } else {
            const { data: productData } = await supabase
              .from('products')
              .select('id')
              .eq('client_id', productId)
              .single();
            if (productData) {
              productUuid = productData.id;
            }
          }
        }

        // Get password reset success email data
        const signinUrl = typeof window !== 'undefined' 
          ? `${window.location.origin}/login`
          : 'http://localhost:3000/login';

        const { data: emailData, error: emailError } = await supabase.rpc(
          'get_password_reset_success_email_data',
          {
            p_user_email: email,
            p_product_id: productUuid,
            p_signin_url: signinUrl,
          }
        );

        if (emailError) {
          logger.error('Error getting password reset success email data', emailError);
          return; // Don't throw - success email is non-critical
        }

        if (!emailData || !emailData.to_email) {
          logger.warn('No password reset success email data returned');
          return;
        }

        // Send email via Edge Function
        const origin = typeof window !== 'undefined' ? window.location.origin : undefined;
        const functionUrl = `${config.supabaseUrl}/functions/v1/send-email`;
        
        const response = await fetch(functionUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${config.supabaseAnonKey}`,
          },
          body: JSON.stringify({
            to: emailData.to_email,
            subject: emailData.subject,
            html: emailData.body_html,
            text: emailData.body_text,
            client_secret: config.clientSecret,
            origin: origin,
          }),
        });

        if (!response.ok) {
          const errorData = await response.json().catch(() => ({ error: 'Unknown error' }));
          logger.error('Failed to send password reset success email', { error: errorData.error });
          return; // Don't throw - success email is non-critical
        }

        logger.info('Password reset success email sent', { to: emailData.to_email });
      } catch (err) {
        logger.error('Error sending password reset success email', err);
        // Don't throw - success email is non-critical
      }
    },
    [supabase, config]
  );

  return { sendSuccessEmail };
};
