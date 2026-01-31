/**
 * Hook for checking if user has a specific role
 */

import { useMemo } from 'react';
import { useAuth } from '../../providers/AuthProvider';
import { parseJWT, extractRoles } from '../../shared/utils';

export interface UseHasRoleReturn {
  hasRole: boolean;
  loading: boolean;
}

export const useHasRole = (role: string): UseHasRoleReturn => {
  const { session, loading } = useAuth();

  const hasRole = useMemo(() => {
    if (!session?.access_token) return false;
    const payload = parseJWT(session.access_token);
    if (!payload) return false;
    const roles = extractRoles(payload);
    return roles.includes(role);
  }, [session?.access_token, role]);

  return {
    hasRole,
    loading,
  };
};
