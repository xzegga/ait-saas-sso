/**
 * Hook for fetching current user permissions
 */

import { useMemo } from 'react';
import { useAuth } from '../../providers/AuthProvider';
import { parseJWT, extractPermissions } from '../../shared/utils';

export interface UsePermissionsReturn {
  permissions: string[];
  loading: boolean;
}

export const usePermissions = (): UsePermissionsReturn => {
  const { session, loading } = useAuth();

  const permissions = useMemo(() => {
    if (!session?.access_token) return [];
    const payload = parseJWT(session.access_token);
    if (!payload) return [];
    return extractPermissions(payload);
  }, [session?.access_token]);

  return {
    permissions,
    loading,
  };
};
