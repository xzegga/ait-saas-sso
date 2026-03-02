/**
 * Hook for fetching and managing organization addresses (by type: billing, shipping, legal, headquarters)
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import type {
  OrganizationAddress,
  OrganizationAddressCreate,
  OrganizationAddressUpdate,
  OrganizationAddressType,
} from '../../shared/types';

export interface UseOrganizationAddressesReturn {
  addresses: OrganizationAddress[];
  loading: boolean;
  error: Error | null;
  addAddress: (data: OrganizationAddressCreate) => Promise<OrganizationAddress | null>;
  updateAddress: (addressType: OrganizationAddressType, data: OrganizationAddressUpdate) => Promise<OrganizationAddress | null>;
  deleteAddress: (addressType: OrganizationAddressType) => Promise<void>;
  refetch: () => Promise<void>;
}

export const useOrganizationAddresses = (organizationId: string | null): UseOrganizationAddressesReturn => {
  const { supabase } = useIDP();
  const [addresses, setAddresses] = useState<OrganizationAddress[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchAddresses = useCallback(async () => {
    if (!organizationId) {
      setAddresses([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const { data, error: fetchError } = await supabase
        .from('organization_addresses')
        .select('*')
        .eq('org_id', organizationId)
        .order('address_type');

      if (fetchError) throw new Error(fetchError.message);
      setAddresses((data || []) as OrganizationAddress[]);
      logger.debug('Organization addresses fetched', { organizationId, count: (data || []).length });
    } catch (err: any) {
      const e = err instanceof Error ? err : new Error(String(err));
      setError(e);
      logger.error('Error fetching organization addresses', err);
      setAddresses([]);
    } finally {
      setLoading(false);
    }
  }, [supabase, organizationId]);

  const addAddress = useCallback(
    async (data: OrganizationAddressCreate): Promise<OrganizationAddress | null> => {
      if (!organizationId) {
        throw new Error('Organization ID not available');
      }

      setError(null);
      try {
        const { data: inserted, error: insertError } = await supabase
          .from('organization_addresses')
          .insert({
            org_id: organizationId,
            address_type: data.address_type,
            line1: data.line1 ?? null,
            line2: data.line2 ?? null,
            city: data.city ?? null,
            state_region: data.state_region ?? null,
            postal_code: data.postal_code ?? null,
            country_code: data.country_code ?? null,
          })
          .select()
          .single();

        if (insertError) throw new Error(insertError.message);
        await fetchAddresses();
        logger.info('Organization address added', { organizationId, type: data.address_type });
        return inserted as OrganizationAddress;
      } catch (err: any) {
        const e = err instanceof Error ? err : new Error(String(err));
        setError(e);
        logger.error('Error adding organization address', err);
        throw e;
      }
    },
    [supabase, organizationId, fetchAddresses]
  );

  const updateAddress = useCallback(
    async (addressType: OrganizationAddressType, data: OrganizationAddressUpdate): Promise<OrganizationAddress | null> => {
      if (!organizationId) {
        throw new Error('Organization ID not available');
      }

      setError(null);
      try {
        const { data: updated, error: updateError } = await supabase
          .from('organization_addresses')
          .update({
            line1: data.line1 ?? null,
            line2: data.line2 ?? null,
            city: data.city ?? null,
            state_region: data.state_region ?? null,
            postal_code: data.postal_code ?? null,
            country_code: data.country_code ?? null,
          })
          .eq('org_id', organizationId)
          .eq('address_type', addressType)
          .select()
          .single();

        if (updateError) throw new Error(updateError.message);
        await fetchAddresses();
        logger.info('Organization address updated', { organizationId, type: addressType });
        return updated as OrganizationAddress;
      } catch (err: any) {
        const e = err instanceof Error ? err : new Error(String(err));
        setError(e);
        logger.error('Error updating organization address', err);
        throw e;
      }
    },
    [supabase, organizationId, fetchAddresses]
  );

  const deleteAddress = useCallback(
    async (addressType: OrganizationAddressType): Promise<void> => {
      if (!organizationId) {
        throw new Error('Organization ID not available');
      }

      setError(null);
      try {
        const { error: deleteError } = await supabase
          .from('organization_addresses')
          .delete()
          .eq('org_id', organizationId)
          .eq('address_type', addressType);

        if (deleteError) throw new Error(deleteError.message);
        await fetchAddresses();
        logger.info('Organization address deleted', { organizationId, type: addressType });
      } catch (err: any) {
        const e = err instanceof Error ? err : new Error(String(err));
        setError(e);
        logger.error('Error deleting organization address', err);
        throw e;
      }
    },
    [supabase, organizationId, fetchAddresses]
  );

  useEffect(() => {
    fetchAddresses();
  }, [fetchAddresses]);

  return {
    addresses,
    loading,
    error,
    addAddress,
    updateAddress,
    deleteAddress,
    refetch: fetchAddresses,
  };
};
