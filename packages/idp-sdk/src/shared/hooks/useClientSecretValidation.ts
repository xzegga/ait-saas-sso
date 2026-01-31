/**
 * Hook for client secret validation
 * Can be used to validate client_secret before critical operations
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { validateClientSecret, getProductIdByClientSecret } from '../validation';
import { logger } from '../logger';

export interface UseClientSecretValidationReturn {
  validate: (productId?: string) => Promise<boolean>;
  getProductId: () => Promise<string | null>;
  isValidating: boolean;
  isValid: boolean | null;
  error: Error | null;
}

/**
 * Hook to validate client_secret
 * @returns Validation functions and state
 */
export const useClientSecretValidation = (): UseClientSecretValidationReturn => {
  const { supabase, config } = useIDP();
  const [isValidating, setIsValidating] = useState(false);
  const [isValid, setIsValid] = useState<boolean | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const validate = useCallback(
    async (productId?: string): Promise<boolean> => {
      if (!config.clientSecret) {
        const err = new Error('clientSecret is not configured');
        setError(err);
        setIsValid(false);
        return false;
      }

      const targetProductId = productId || config.productId;
      if (!targetProductId) {
        const err = new Error('productId is required for validation');
        setError(err);
        setIsValid(false);
        return false;
      }

      setIsValidating(true);
      setError(null);

      try {
        const result = await validateClientSecret(
          supabase,
          targetProductId,
          config.clientSecret
        );

        setIsValid(result);
        if (!result) {
          setError(new Error('Invalid client_secret'));
        }

        return result;
      } catch (err: any) {
        const error = err instanceof Error ? err : new Error(err?.message || 'Validation failed');
        setError(error);
        setIsValid(false);
        logger.error('Client secret validation error', error);
        return false;
      } finally {
        setIsValidating(false);
      }
    },
    [supabase, config]
  );

  const getProductId = useCallback(async (): Promise<string | null> => {
    if (!config.clientSecret) {
      setError(new Error('clientSecret is not configured'));
      return null;
    }

    setIsValidating(true);
    setError(null);

    try {
      const productId = await getProductIdByClientSecret(
        supabase,
        config.clientSecret
      );

      if (productId) {
        setIsValid(true);
      } else {
        setIsValid(false);
        setError(new Error('Invalid client_secret'));
      }

      return productId;
    } catch (err: any) {
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to get product_id');
      setError(error);
      setIsValid(false);
      logger.error('Get product_id by client_secret error', error);
      return null;
    } finally {
      setIsValidating(false);
    }
  }, [supabase, config]);

  return {
    validate,
    getProductId,
    isValidating,
    isValid,
    error,
  };
};
