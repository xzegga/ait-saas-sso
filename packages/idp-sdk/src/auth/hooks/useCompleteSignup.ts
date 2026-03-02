/**
 * Hook for completing user signup after email verification
 * Creates organization and subscription for a verified user
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { AuthenticationError, ValidationError } from '../../shared/errors';
import { useSendSubscriptionPurchasedEmail } from './useSendSubscriptionPurchasedEmail';

export interface CompleteSignupParams {
  productId: string;
  planId: string;
  billingInterval?: string; // Billing interval key (e.g., 'month', 'year')
  orgName?: string;
  useUserName: boolean;
}

export interface CompleteSignupResult {
  orgId: string;
  subscriptionId: string;
  status: 'trial' | 'active';
  trialDays?: number;
  trialEndsAt?: string;
}

export interface UseCompleteSignupReturn {
  completeSignup: (params: CompleteSignupParams) => Promise<CompleteSignupResult>;
  loading: boolean;
  error: Error | null;
}

export const useCompleteSignup = (): UseCompleteSignupReturn => {
  const { supabase, config } = useIDP();
  const { sendSubscriptionPurchasedEmail } = useSendSubscriptionPurchasedEmail();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const completeSignup = useCallback(
    async (params: CompleteSignupParams): Promise<CompleteSignupResult> => {
      setLoading(true);
      setError(null);

      try {
        // Validate product ID
        if (!params.productId) {
          throw new ValidationError('Product ID is required');
        }

        // Validate plan ID
        if (!params.planId) {
          throw new ValidationError('Plan ID is required');
        }

        // Get current user
        const { data: { user }, error: userError } = await supabase.auth.getUser();

        if (userError || !user) {
          throw new AuthenticationError('User not authenticated. Please verify your email first.');
        }

        // Check if user is verified
        if (!user.email_confirmed_at) {
          throw new AuthenticationError('Email not verified. Please verify your email first.');
        }

        logger.debug('Completing signup', { userId: user.id, productId: params.productId, planId: params.planId });

        // Call the complete signup function to create org and subscription
        const { data: signupData, error: signupError } = await supabase.rpc(
          'fn_complete_user_signup',
          {
            p_user_id: user.id,
            p_product_id: params.productId,
            p_plan_id: params.planId,
            p_billing_interval: params.billingInterval || 'month',
            p_org_name: params.orgName || null,
            p_use_user_name: params.useUserName,
          }
        );

        if (signupError) {
          logger.error('Complete signup RPC error', signupError);
          throw new AuthenticationError(signupError.message || 'Signup completion failed');
        }

        if (!signupData?.success) {
          const errorMsg = signupData?.error || 'Signup completion failed';
          logger.error('Complete signup failed', { error: errorMsg, data: signupData });
          throw new AuthenticationError(errorMsg);
        }

        logger.info('Signup completed successfully', {
          userId: user.id,
          orgId: signupData.org_id,
          subscriptionId: signupData.subscription_id,
          status: signupData.status,
        });

        // Send welcome email and admin notification
        let productUuid: string | null = null;
        try {
          if (params.productId.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) {
            productUuid = params.productId;
          } else {
            const { data: productData } = await supabase
              .from('products')
              .select('id')
              .eq('client_id', params.productId)
              .single();
            if (productData) {
              productUuid = productData.id;
            }
          }
        } catch (err) {
          logger.warn('Could not determine product UUID for email', err);
        }

        // Note: Welcome email is now sent after OTP verification in useVerifyOtp
        // We don't send it here to avoid duplicate emails

        // Send subscription purchased email
        if (productUuid && signupData.subscription_id) {
          try {
            logger.debug('Sending subscription purchased email', { 
              userId: user.id, 
              subscriptionId: signupData.subscription_id,
              productId: productUuid 
            });
            await sendSubscriptionPurchasedEmail(user.id, signupData.subscription_id, productUuid);
            logger.info('Subscription purchased email sent successfully', {
              userId: user.id,
              subscriptionId: signupData.subscription_id,
            });
          } catch (err) {
            logger.error('Error sending subscription purchased email', {
              error: err,
              userId: user.id,
              subscriptionId: signupData.subscription_id,
            });
            // Don't fail - email is non-critical, but log the full error
          }
        } else {
          logger.warn('Skipping subscription purchased email', {
            hasProductUuid: !!productUuid,
            hasSubscriptionId: !!signupData.subscription_id,
          });
        }

        // Send admin notification email (only when subscription is purchased)
        if (productUuid && signupData.subscription_id) {
          try {
            logger.debug('Sending admin notification email', {
              userId: user.id,
              productId: productUuid,
              subscriptionId: signupData.subscription_id,
            });
            const { data: adminEmailData, error: adminEmailError } = await supabase.rpc(
              'get_admin_new_user_notification_data',
              {
                p_user_id: user.id,
                p_product_id: productUuid,
              }
            );

            if (adminEmailError) {
              logger.error('Error getting admin notification email data', {
                error: adminEmailError,
                userId: user.id,
                productId: productUuid,
              });
            } else if (adminEmailData?.success && adminEmailData.recipients) {
              const recipients = adminEmailData.recipients as string[];
              logger.debug('Sending admin notification emails', { 
                recipientsCount: recipients.length,
                recipients 
              });
              const origin = typeof window !== 'undefined' ? window.location.origin : undefined;
              const functionUrl = `${config.supabaseUrl}/functions/v1/send-email`;
              
              for (const adminEmail of recipients) {
                try {
                  logger.debug('Sending admin notification email', { to: adminEmail });
                  const response = await fetch(functionUrl, {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': `Bearer ${config.supabaseAnonKey}`,
                    },
                    body: JSON.stringify({
                      to: adminEmail,
                      subject: adminEmailData.subject,
                      html: adminEmailData.html,
                      text: adminEmailData.text,
                      from_name: adminEmailData.from_name,
                      client_secret: config.clientSecret,
                      origin: origin,
                    }),
                  });

                  if (response.ok) {
                    const responseData = await response.json().catch(() => ({}));
                    logger.info('Admin notification email sent successfully', { 
                      to: adminEmail,
                      response: responseData 
                    });
                  } else {
                    const errorData = await response.json().catch(() => ({ error: 'Unknown error' }));
                    logger.error('Failed to send admin notification email', { 
                      to: adminEmail, 
                      status: response.status,
                      error: errorData 
                    });
                  }
                } catch (sendError) {
                  logger.error('Error sending admin notification email', { 
                    to: adminEmail, 
                    error: sendError 
                  });
                }
              }
            } else {
              logger.warn('No admin notification email data or recipients', {
                hasError: !!adminEmailError,
                hasData: !!adminEmailData,
                hasSuccess: adminEmailData?.success,
                hasRecipients: !!adminEmailData?.recipients,
                error: adminEmailError,
              });
            }
          } catch (err) {
            logger.error('Error sending admin notification email', {
              error: err,
              userId: user.id,
              productId: productUuid,
            });
            // Don't fail - admin email is non-critical
          }
        } else {
          logger.debug('Skipping admin notification email', {
            hasProductUuid: !!productUuid,
            hasSubscriptionId: !!signupData.subscription_id,
          });
        }

        return {
          orgId: signupData.org_id,
          subscriptionId: signupData.subscription_id,
          status: signupData.status,
          trialDays: signupData.trial_days,
          trialEndsAt: signupData.trial_ends_at,
        };
      } catch (err: any) {
        logger.error('Complete signup error', err);
        const error = err instanceof Error ? err : new AuthenticationError(err?.message || 'Signup completion failed');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase, config, sendSubscriptionPurchasedEmail]
  );

  return { completeSignup, loading, error };
};
