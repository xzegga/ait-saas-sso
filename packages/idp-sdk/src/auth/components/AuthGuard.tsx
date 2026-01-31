/**
 * Auth Guard Component - Route protection wrapper
 */

import React, { ReactNode, useEffect } from 'react';
import { useAuth } from '../../providers/AuthProvider';
import { logger } from '../../shared/logger';

export interface AuthGuardProps {
  children: ReactNode;
  fallback?: ReactNode;
  redirectTo?: string;
  onUnauthenticated?: () => void;
}

export const AuthGuard: React.FC<AuthGuardProps> = ({
  children,
  fallback = null,
  redirectTo,
  onUnauthenticated,
}: AuthGuardProps) => {
  const { user, loading } = useAuth();

  useEffect(() => {
    if (!loading && !user) {
      logger.debug('User not authenticated, triggering redirect');
      if (onUnauthenticated) {
        onUnauthenticated();
      } else if (redirectTo && typeof window !== 'undefined') {
        window.location.href = redirectTo;
      }
    }
  }, [user, loading, redirectTo, onUnauthenticated]);

  if (loading) {
    return <>{fallback}</>;
  }

  if (!user) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
};
