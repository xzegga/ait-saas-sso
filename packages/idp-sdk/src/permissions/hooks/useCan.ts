/**
 * Hook for checking specific permission
 */

import { useMemo } from 'react';
import { usePermissions } from './usePermissions';

export interface UseCanReturn {
  can: boolean;
  loading: boolean;
}

export const useCan = (permission: string): UseCanReturn => {
  const { permissions, loading } = usePermissions();

  const can = useMemo(() => {
    return permissions.includes(permission);
  }, [permissions, permission]);

  return {
    can,
    loading,
  };
};
