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
  const [resolvedOrgId, setResolvedOrgId] = useState<string | null>(null);

  // Resolve org ID: explicit param > config > JWT app_metadata > fetch from org_members (fallback)
  const resolveOrgId = useCallback(async (): Promise<string | null> => {
    if (organizationId) return organizationId;
    if (config.organizationId) return config.organizationId;
    if (session?.access_token) {
      const fromJwt = getOrganizationId(parseJWT(session.access_token));
      if (fromJwt) return fromJwt;
      // Fallback: user may have org_members row but JWT not yet refreshed (e.g. right after signup)
      try {
        const { data } = await supabase
          .from('org_members')
          .select('org_id')
          .eq('user_id', session.user.id)
          .limit(1)
          .maybeSingle();
        if (data?.org_id) {
          logger.debug('Resolved org_id from org_members (JWT had no org_id)', { org_id: data.org_id });
          return data.org_id as string;
        }
      } catch (_) {
        // ignore
      }
    }
    return null;
  }, [organizationId, config.organizationId, session, supabase]);

  const fetchOrganization = useCallback(async () => {
    const orgId = await resolveOrgId();
    setResolvedOrgId(orgId);

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
        .maybeSingle();

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      setOrganization(data as Organization | null);
      if (data) {
        logger.info('Organization fetched successfully');
      } else {
        logger.debug('No organization found for id', { organizationId: orgId });
      }
    } catch (err: any) {
      logger.error('Error fetching organization', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch organization');
      setError(error);
      setOrganization(null);
    } finally {
      setLoading(false);
    }
  }, [supabase, resolveOrgId]);

  const updateOrganization = useCallback(
    async (updates: OrganizationUpdate) => {
      const orgId = resolvedOrgId ?? (await resolveOrgId());
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
          .maybeSingle();

        if (updateError) {
          throw new Error(updateError.message);
        }

        if (data) {
          setOrganization(data as Organization);
        }
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
    [supabase, resolvedOrgId, resolveOrgId]
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
