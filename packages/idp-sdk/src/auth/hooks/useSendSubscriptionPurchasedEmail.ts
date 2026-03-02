/**
 * Hook for sending subscription purchased email after successful signup completion
 */

import { useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface UseSendSubscriptionPurchasedEmailReturn {
  sendSubscriptionPurchasedEmail: (userId: string, subscriptionId: string, productId?: string) => Promise<void>;
}

export const useSendSubscriptionPurchasedEmail = (): UseSendSubscriptionPurchasedEmailReturn => {
  const { supabase, config } = useIDP();

  const sendSubscriptionPurchasedEmail = useCallback(
    async (userId: string, subscriptionId: string, productId?: string) => {
      try {
        logger.debug('Sending subscription purchased email', { userId, subscriptionId, productId });

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

        // Get subscription purchased email data
        const dashboardUrl = typeof window !== 'undefined' 
          ? `${window.location.origin}/dashboard`
          : 'http://localhost:3000/dashboard';

        logger.debug('Calling get_subscription_purchased_email_data RPC', {
          userId,
          subscriptionId,
          productUuid,
          dashboardUrl,
        });

        const { data: emailData, error: emailError } = await supabase.rpc(
          'get_subscription_purchased_email_data',
          {
            p_user_id: userId,
            p_subscription_id: subscriptionId,
            p_product_id: productUuid,
            p_dashboard_url: dashboardUrl,
          }
        );

        if (emailError) {
          logger.error('Error getting subscription purchased email data', {
            error: emailError,
            errorCode: emailError.code,
            errorMessage: emailError.message,
            errorDetails: emailError.details,
            errorHint: emailError.hint,
            userId,
            subscriptionId,
            productId: productUuid,
          });
          return; // Don't throw - log and return
        }

        logger.debug('Subscription purchased email data received', {
          emailData,
          hasToEmail: !!emailData?.to_email,
          hasSubject: !!emailData?.subject,
          hasHtml: !!emailData?.body_html,
        });

        if (!emailData || !emailData.to_email) {
          logger.warn('No subscription purchased email data returned', {
            emailData,
            userId,
            subscriptionId,
            productId: productUuid,
          });
          return; // Don't throw - log and return
        }

        logger.debug('Subscription purchased email data retrieved', {
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
          logger.error('Failed to send subscription purchased email', { 
            status: response.status,
            error: errorData,
            to: emailData.to_email,
            functionUrl,
          });
          return; // Don't throw - log and return
        }

        const responseData = await response.json().catch(() => ({}));
        logger.info('Subscription purchased email sent successfully', { 
          to: emailData.to_email,
          response: responseData,
        });
      } catch (err) {
        logger.error('Error sending subscription purchased email', {
          error: err,
          userId,
          subscriptionId,
          productId,
        });
        // Don't throw - log the error but don't break the flow
      }
    },
    [supabase, config]
  );

  return { sendSubscriptionPurchasedEmail };
};
