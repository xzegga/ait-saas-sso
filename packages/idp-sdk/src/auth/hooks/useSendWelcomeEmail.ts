/**
 * Hook for sending welcome email after successful email verification
 */

import { useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface UseSendWelcomeEmailReturn {
  sendWelcomeEmail: (userId: string, productId?: string) => Promise<void>;
}

export const useSendWelcomeEmail = (): UseSendWelcomeEmailReturn => {
  const { supabase, config } = useIDP();

  const sendWelcomeEmail = useCallback(
    async (userId: string, productId?: string) => {
      try {
        logger.debug('Sending welcome email', { userId, productId });

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

        // Get welcome email data
        const dashboardUrl = typeof window !== 'undefined' 
          ? `${window.location.origin}/dashboard`
          : 'http://localhost:3000/dashboard';

        logger.debug('Calling get_welcome_email_data RPC', {
          userId,
          productUuid,
          dashboardUrl,
        });

        const { data: emailData, error: emailError } = await supabase.rpc(
          'get_welcome_email_data',
          {
            p_user_id: userId,
            p_product_id: productUuid,
            p_dashboard_url: dashboardUrl,
          }
        );

        if (emailError) {
          logger.error('Error getting welcome email data', {
            error: emailError,
            errorCode: emailError.code,
            errorMessage: emailError.message,
            errorDetails: emailError.details,
            errorHint: emailError.hint,
            userId,
            productId: productUuid,
          });
          return; // Don't throw - log and return
        }

        logger.debug('Welcome email data received', {
          emailData,
          hasToEmail: !!emailData?.to_email,
          hasSubject: !!emailData?.subject,
          hasHtml: !!emailData?.body_html,
        });

        if (!emailData || !emailData.to_email) {
          logger.warn('No welcome email data returned', {
            emailData,
            userId,
            productId: productUuid,
          });
          return; // Don't throw - log and return
        }

        logger.debug('Welcome email data retrieved', {
          to: emailData.to_email,
          hasSubject: !!emailData.subject,
          hasHtml: !!emailData.body_html,
        });

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
          logger.error('Failed to send welcome email', { 
            status: response.status,
            statusText: response.statusText,
            error: errorData,
            to: emailData.to_email,
            functionUrl,
          });
          return; // Don't throw - log and return
        }

        const responseData = await response.json().catch(() => ({}));
        logger.info('Welcome email sent successfully', { 
          to: emailData.to_email,
          response: responseData,
        });
      } catch (err) {
        logger.error('Error sending welcome email', {
          error: err,
          errorMessage: err instanceof Error ? err.message : String(err),
          errorStack: err instanceof Error ? err.stack : undefined,
          userId,
          productId,
        });
        // Don't throw - log the error but don't break the flow
        // The welcome email is non-critical, but we log it for debugging
      }
    },
    [supabase, config]
  );

  return { sendWelcomeEmail };
};
