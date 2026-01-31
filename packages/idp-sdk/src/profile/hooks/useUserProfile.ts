/**
 * Hook for fetching and updating user profile
 */

import { useState, useCallback, useEffect } from 'react';
import { useIDP } from '../../providers/IDPProvider';
import { useAuth } from '../../providers/AuthProvider';
import { logger } from '../../shared/logger';
import type { User, UserUpdate } from '../../shared/types';

export interface UseUserProfileReturn {
  profile: User | null;
  loading: boolean;
  error: Error | null;
  updateProfile: (updates: UserUpdate) => Promise<void>;
  updating: boolean;
  refetch: () => Promise<void>;
}

export const useUserProfile = (): UseUserProfileReturn => {
  const { supabase } = useIDP();
  const { user: authUser } = useAuth();
  const [profile, setProfile] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [updating, setUpdating] = useState(false);

  const fetchProfile = useCallback(async () => {
    if (!authUser?.id) {
      setProfile(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      logger.debug('Fetching user profile', { userId: authUser.id });

      const { data, error: fetchError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authUser.id)
        .single();

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      setProfile(data as User);
      logger.info('User profile fetched successfully');
    } catch (err: any) {
      logger.error('Error fetching user profile', err);
      const error = err instanceof Error ? err : new Error(err?.message || 'Failed to fetch profile');
      setError(error);
    } finally {
      setLoading(false);
    }
  }, [supabase, authUser?.id]);

  const updateProfile = useCallback(
    async (updates: UserUpdate) => {
      if (!authUser?.id) {
        throw new Error('User not authenticated');
      }

      setUpdating(true);
      setError(null);

      try {
        logger.debug('Updating user profile', { userId: authUser.id, updates });

        const { data, error: updateError } = await supabase
          .from('profiles')
          .update(updates)
          .eq('id', authUser.id)
          .select()
          .single();

        if (updateError) {
          throw new Error(updateError.message);
        }

        setProfile(data as User);
        logger.info('User profile updated successfully');
      } catch (err: any) {
        logger.error('Error updating user profile', err);
        const error = err instanceof Error ? err : new Error(err?.message || 'Failed to update profile');
        setError(error);
        throw error;
      } finally {
        setUpdating(false);
      }
    },
    [supabase, authUser?.id]
  );

  // Fetch profile on mount and when authUser changes
  useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);

  return {
    profile,
    loading,
    error,
    updateProfile,
    updating,
    refetch: fetchProfile,
  };
};
