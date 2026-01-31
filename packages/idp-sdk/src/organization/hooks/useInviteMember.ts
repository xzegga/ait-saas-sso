/**
 * Hook for inviting members to organization
 */

import { useState, useCallback } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { ValidationError } from '../../shared/errors';
import { isValidEmail } from '../../shared/utils';

export interface InviteMemberData {
  email: string;
  role: string;
  productRoles?: { productId: string; role: string }[];
}

export interface UseInviteMemberReturn {
  inviteMember: (data: InviteMemberData) => Promise<void>;
  loading: boolean;
  error: Error | null;
}

export const useInviteMember = (organizationId: string): UseInviteMemberReturn => {
  const { supabase } = useIDP();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const inviteMember = useCallback(
    async (data: InviteMemberData) => {
      setLoading(true);
      setError(null);

      try {
        if (!isValidEmail(data.email)) {
          throw new ValidationError('Invalid email address');
        }

        logger.debug('Inviting member', { organizationId, email: data.email });

        // Create invitation (this would typically call an Edge Function or API endpoint)
        // For now, we'll create a placeholder that would need backend implementation
        const { error: inviteError } = await supabase.rpc('invite_member', {
          p_org_id: organizationId,
          p_email: data.email,
          p_role: data.role,
          p_product_roles: data.productRoles || [],
        });

        if (inviteError) {
          throw new Error(inviteError.message);
        }

        logger.info('Member invitation sent successfully');
      } catch (err: any) {
        logger.error('Error inviting member', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to invite member');
        setError(error);
        throw error;
      } finally {
        setLoading(false);
      }
    },
    [supabase, organizationId]
  );

  return { inviteMember, loading, error };
};
