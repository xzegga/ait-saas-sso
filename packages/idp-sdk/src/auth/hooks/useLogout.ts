/**
 * Hook for logout functionality
 */

import { useCallback, useState } from 'react';
import { useAuth } from '../../providers/AuthProvider';
import { logger } from '../../shared/logger';

export interface UseLogoutReturn {
  logout: () => Promise<void>;
  loading: boolean;
}

export const useLogout = (): UseLogoutReturn => {
  const { signOut } = useAuth();
  const [loading, setLoading] = useState(false);

  const logout = useCallback(async () => {
    setLoading(true);
    try {
      logger.debug('Logging out');
      await signOut();
      logger.info('Logout successful');
    } catch (error) {
      logger.error('Logout failed', error);
      throw error;
    } finally {
      setLoading(false);
    }
  }, [signOut]);

  return { logout, loading };
};
