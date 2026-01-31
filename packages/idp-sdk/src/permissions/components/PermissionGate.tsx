/**
 * Permission Gate Component - Conditional rendering based on permissions
 */

import React, { ReactNode } from 'react';
import { useCan } from '../hooks/useCan';

export interface PermissionGateProps {
  permission: string;
  children: ReactNode;
  fallback?: ReactNode;
  loading?: ReactNode;
}

export const PermissionGate: React.FC<PermissionGateProps> = ({
  permission,
  children,
  fallback = null,
  loading = null,
}: PermissionGateProps) => {
  const { can, loading: isLoading } = useCan(permission);

  if (isLoading) {
    return <>{loading}</>;
  }

  if (!can) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
};
