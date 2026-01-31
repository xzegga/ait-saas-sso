/**
 * Main IDP Provider component
 */

import React, { createContext, useContext, useMemo, ReactNode, useEffect, useState } from 'react';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import type { IDPConfig } from '../shared/types';
import { ConfigurationError } from '../shared/errors';
import { logger } from '../shared/logger';
import { validateClientSecret, getProductIdByClientSecret } from '../shared/validation';

interface IDPContextValue {
  supabase: SupabaseClient;
  config: IDPConfig;
  isValidating?: boolean;
  validationError?: Error | null;
}

const IDPContext = createContext<IDPContextValue | null>(null);

export interface IDPProviderProps {
  children: ReactNode;
  supabaseUrl: string;
  supabaseAnonKey: string;
  productId?: string;
  organizationId?: string;
  clientSecret?: string;
}

export const IDPProvider: React.FC<IDPProviderProps> = ({
  children,
  supabaseUrl,
  supabaseAnonKey,
  productId,
  organizationId,
  clientSecret,
}: IDPProviderProps) => {
  const [isValidating, setIsValidating] = useState(false);
  const [validationError, setValidationError] = useState<Error | null>(null);

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new ConfigurationError(
      'supabaseUrl and supabaseAnonKey are required'
    );
  }

  const supabase = useMemo(() => {
    logger.debug('Initializing Supabase client', { supabaseUrl });
    return createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
  }, [supabaseUrl, supabaseAnonKey]);

  // Validate client_secret if both productId and clientSecret are provided
  useEffect(() => {
    const validate = async () => {
      // If clientSecret is provided, it must be validated
      if (clientSecret) {
        setIsValidating(true);
        setValidationError(null);

        try {
          let validatedProductId: string | null = null;

          // If productId is provided, validate it matches the client_secret
          if (productId) {
            const isValid = await validateClientSecret(
              supabase,
              productId,
              clientSecret
            );

            if (!isValid) {
              throw new ConfigurationError(
                'Invalid client_secret for the provided product_id'
              );
            }

            validatedProductId = productId;
          } else {
            // If productId is not provided, get it from client_secret
            validatedProductId = await getProductIdByClientSecret(
              supabase,
              clientSecret
            );

            if (!validatedProductId) {
              throw new ConfigurationError(
                'Invalid client_secret. No matching product found.'
              );
            }
          }

          logger.info('Client secret validated successfully', {
            productId: validatedProductId,
          });
        } catch (err: any) {
          const error = err instanceof Error
            ? err
            : new ConfigurationError(err?.message || 'Client secret validation failed');
          
          logger.error('Client secret validation failed', error);
          setValidationError(error);
        } finally {
          setIsValidating(false);
        }
      }
    };

    validate();
  }, [supabase, productId, clientSecret]);

  const config: IDPConfig = useMemo(
    () => ({
      supabaseUrl,
      supabaseAnonKey,
      productId,
      organizationId,
      clientSecret,
    }),
    [supabaseUrl, supabaseAnonKey, productId, organizationId, clientSecret]
  );

  const value = useMemo(
    () => ({
      supabase,
      config,
      isValidating,
      validationError,
    }),
    [supabase, config, isValidating, validationError]
  );

  return <IDPContext.Provider value={value}>{children}</IDPContext.Provider>;
};

export const useIDP = (): IDPContextValue => {
  const context = useContext(IDPContext);
  if (!context) {
    throw new ConfigurationError(
      'useIDP must be used within an IDPProvider'
    );
  }
  return context;
};
