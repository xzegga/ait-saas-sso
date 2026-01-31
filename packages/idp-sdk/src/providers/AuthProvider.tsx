/**
 * Authentication Provider component
 */

import React, { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import type { User, Session } from '@supabase/supabase-js';
import { useIDP } from './IDPProvider';
import { logger } from '../shared/logger';
import { AuthenticationError } from '../shared/errors';

interface AuthContextValue {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signOut: () => Promise<void>;
  refreshSession: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }: AuthProviderProps) => {
  const { supabase } = useIDP();
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshSession = useCallback(async () => {
    try {
      logger.debug('Refreshing session');
      const { data, error } = await supabase.auth.refreshSession();
      if (error) throw error;
      setSession(data.session);
      setUser(data.user);
    } catch (error: any) {
      logger.error('Error refreshing session', error);
      setSession(null);
      setUser(null);
    }
  }, [supabase]);

  const signOut = useCallback(async () => {
    try {
      logger.debug('Signing out');
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      setSession(null);
      setUser(null);
    } catch (error: any) {
      logger.error('Error signing out', error);
      throw new AuthenticationError(error.message);
    }
  }, [supabase]);

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session }, error }) => {
      if (error) {
        logger.error('Error getting session', error);
      }
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      logger.debug('Auth state changed', { event: _event });
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [supabase]);

  const value: AuthContextValue = {
    user,
    session,
    loading,
    signOut,
    refreshSession,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = (): AuthContextValue => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new AuthenticationError('useAuth must be used within an AuthProvider');
  }
  return context;
};
