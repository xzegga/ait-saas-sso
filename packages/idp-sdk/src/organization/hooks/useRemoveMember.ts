/**
 * Hook for removing members from organization
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface UseRemoveMemberReturn {
  removeMember: (memberId: string) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useRemoveMember = (organizationId: string): UseRemoveMemberReturn => {
  const { supabase } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const removeMember = useCallback(
    async (memberId: string) => {
      setLoading(true);
      setError(null);

      try {
        logger.debug('Removing member', { organizationId, memberId });

        const { error: removeError } = await supabase
          .from('org_members')
          .update({ deleted_at: new Date().toISOString() })
          .eq('id', memberId)
          .eq('org_id', organizationId);

        if (removeError) {
          throw new Error(removeError.message);
        }

        logger.info('Member removed successfully');
      } catch (err: any) {
        logger.error('Error removing member', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to remove member');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase, organizationId]
  );

  return { removeMember, loading, error };
};
