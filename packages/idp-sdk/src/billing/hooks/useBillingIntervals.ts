/**
 * Hook for fetching available billing intervals
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';

export interface BillingIntervalData {
  key: string;
  label: string;
  description?: string;
  days?: number;
  sort_order: number;
}

export interface UseBillingIntervalsReturn {
  intervals: BillingIntervalData[];
  loading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

export const useBillingIntervals = (): UseBillingIntervalsReturn => {
  const { supabase } = useIDP();
  const [intervals, setIntervals] = useState<BillingIntervalData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchIntervals = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const { data, error: fetchError } = await supabase
        .from('billing_intervals')
        .select('key, label, description, days, sort_order')
        .eq('is_active', true)
        .is('deleted_at', null)
        .order('sort_order', { ascending: true });

      if (fetchError) {
        throw new Error(`Failed to fetch billing intervals: ${fetchError.message}`);
      }

      setIntervals(data || []);
    } catch (err: any) {
      logger.error('Error fetching billing intervals', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch intervals');
      setError(error);
      setIntervals([]);
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    fetchIntervals();
  }, [fetchIntervals]);

  return {
    intervals,
    loading,
    error,
    refetch: fetchIntervals,
  };
};
