/**
 * Client Secret Validation
 * Validates client_secret against the IDP backend
 */

import { SupabaseClient } from '@supabase/supabase-js';
import { ConfigurationError } from './errors';
import { logger } from './logger';

/**
 * Validates a client_secret against the IDP
 * @param supabase - Supabase client instance
 * @param productId - Product ID to validate
 * @param clientSecret - Client secret to validate
 * @returns Promise<boolean> - true if valid, false otherwise
 */
export const validateClientSecret = async (
  supabase: SupabaseClient,
  productId: string,
  clientSecret: string
): Promise<boolean> => {
  if (!productId || !clientSecret) {
    logger.warn('Missing productId or clientSecret for validation');
    return false;
  }

  try {
    logger.debug('Validating client_secret', { productId });

    const { data, error } = await supabase.rpc('validate_client_secret', {
      p_product_id: productId,
      p_client_secret: clientSecret,
    });

    if (error) {
      logger.error('Error validating client_secret', error);
      return false;
    }

    const isValid = data === true;
    
    if (isValid) {
      logger.info('Client secret validated successfully', { productId });
    } else {
      logger.warn('Invalid client_secret', { productId });
    }

    return isValid;
  } catch (err: any) {
    logger.error('Exception validating client_secret', err);
    return false;
  }
};

/**
 * Gets product_id from client_secret
 * Useful for validating client_secret without knowing product_id
 * @param supabase - Supabase client instance
 * @param clientSecret - Client secret to validate
 * @returns Promise<string | null> - product_id if valid, null otherwise
 */
export const getProductIdByClientSecret = async (
  supabase: SupabaseClient,
  clientSecret: string
): Promise<string | null> => {
  if (!clientSecret) {
    logger.warn('Missing clientSecret for product lookup');
    return null;
  }

  try {
    logger.debug('Getting product_id by client_secret');

    const { data, error } = await supabase.rpc('get_product_by_client_secret', {
      p_client_secret: clientSecret,
    });

    if (error) {
      logger.error('Error getting product_id by client_secret', error);
      return null;
    }

    if (data) {
      logger.info('Product found by client_secret', { productId: data });
      return data;
    }

    logger.warn('No product found for client_secret');
    return null;
  } catch (err: any) {
    logger.error('Exception getting product_id by client_secret', err);
    return null;
  }
};
