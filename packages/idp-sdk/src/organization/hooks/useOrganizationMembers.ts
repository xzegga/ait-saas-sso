/**
 * Hook for fetching organization members
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import type { OrganizationMember } from '../../shared/types';

export interface UseOrganizationMembersReturn {
  members: OrganizationMember[];
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export const useOrganizationMembers = (organizationId: string): UseOrganizationMembersReturn => {
  const { supabase } = useIDP();
  const [members, setMembers] = useState<OrganizationMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchMembers = useCallback(async () => {
    if (!organizationId) {
      setMembers([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching organization members', { organizationId });

      const { data, error: fetchError } = await supabase
        .from('org_members')
        .select('*, user:profiles(*), organization:organizations(*)')
        .eq('org_id', organizationId)
        .is('deleted_at', null);

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      setMembers((data || []) as OrganizationMember[]);
      logger.info('Organization members fetched successfully');
    } catch (err: any) {
      logger.error('Error fetching organization members', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch members');
      setError(error);
    } finally {
      setLoading(false);
    }
  }, [supabase, organizationId]);

  useEffect(() => {
    fetchMembers();
  }, [fetchMembers]);

  return {
    members,
    loading,
    error,
    refetch: fetchMembers,
  };
};
