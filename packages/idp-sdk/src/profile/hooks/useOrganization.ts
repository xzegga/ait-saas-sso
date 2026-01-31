/**
 * Hook for fetching and updating organization profile
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { useAuth } from '../../providers/AuthProvider';
import { logger } from '../../shared/logger';
import type { Organization, OrganizationUpdate } from '../../shared/types';
import { parseJWT, getOrganizationId } from '../../shared/utils';

export interface UseOrganizationReturn {
  organization: Organization | null;
  loading: boolean;
  error: Error | null;
  updateOrganization: (updates: OrganizationUpdate) => Promise<void>;
  updating: boolean;
  refetch: () => Promise<void>;
}

export const useOrganization = (organizationId?: string): UseOrganizationReturn => {
  const { supabase, config } = useIDP();
  const { session } = useAuth();
  const [organization, setOrganization] = useState<Organization | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [updating, setUpdating] = useState(false);

  // Determine which organization ID to use
  const orgId = organizationId || config.organizationId || (session ? getOrganizationId(parseJWT(session.access_token)) : null);

  const fetchOrganization = useCallback(async () => {
    if (!orgId) {
      setOrganization(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching organization', { organizationId: orgId });

      const { data, error: fetchError } = await supabase
        .from('organizations')
        .select('*')
        .eq('id', orgId)
        .single();

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      setOrganization(data as Organization);
      logger.info('Organization fetched successfully');
    } catch (err: any) {
      logger.error('Error fetching organization', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch organization');
      setError(error);
    } finally {
      setLoading(false);
    }
  }, [supabase, orgId]);

  const updateOrganization = useCallback(
    async (updates: OrganizationUpdate) => {
      if (!orgId) {
        throw new Error('Organization ID not available');
      }

      setUpdating(true);
      setError(null);

      try {
        logger.debug('Updating organization', { organizationId: orgId, updates });

        const { data, error: updateError } = await supabase
          .from('organizations')
          .update(updates)
          .eq('id', orgId)
          .select()
          .single();

        if (updateError) {
          throw new Error(updateError.message);
        }

        setOrganization(data as Organization);
        logger.info('Organization updated successfully');
      } catch (err: any) {
        logger.error('Error updating organization', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to update organization');
        setError(error);
        throw error;
      } finally {
        setUpdating(false);
      }
    },
    [supabase, orgId]
  );

  useEffect(() => {
    fetchOrganization();
  }, [fetchOrganization]);

  return {
    organization,
    loading,
    error,
    updateOrganization,
    updating,
    refetch: fetchOrganization,
  };
};
