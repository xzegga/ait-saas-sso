/**
 * Payment Provider component (for future use)
 */

import React, { createContext, useContext, ReactNode } from 'react';
import { useIDP } from './IDPProvider';
import { logger } from '../shared/logger';

interface PaymentContextValue {
  // Future payment-related state and methods will go here
  initialized: boolean;
}

const PaymentContext = createContext<PaymentContextValue | null>(null);

export interface PaymentProviderProps {
  children: ReactNode;
}

export const PaymentProvider: React.FC<PaymentProviderProps> = ({ children }: PaymentProviderProps) => {
  logger.debug('PaymentProvider initialized');

  const value: PaymentContextValue = {
    initialized: true,
  };

  return <PaymentContext.Provider value={value}>{children}</PaymentContext.Provider>;
};

export const usePayment = (): PaymentContextValue => {
  const context = useContext(PaymentContext);
  if (!context) {
    throw new Error('usePayment must be used within a PaymentProvider');
  }
  return context;
};
