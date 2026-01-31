/**
 * Feature Flag Component - Conditional rendering based on entitlements
 */

import React, { ReactNode } from 'react';
import { usePermissions } from '../hooks/usePermissions';

export interface FeatureFlagProps {
  feature: string;
  children: ReactNode;
  fallback?: ReactNode;
  loading?: ReactNode;
}

export const FeatureFlag: React.FC<FeatureFlagProps> = ({
  feature,
  children,
  fallback = null,
  loading = null,
}: FeatureFlagProps) => {
  const { permissions, loading: isLoading } = usePermissions();

  if (isLoading) {
    return <>{loading}</>;
  }

  // Check if user has the feature entitlement
  const hasFeature = permissions.includes(`feature:${feature}`) || permissions.includes(feature);

  if (!hasFeature) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
};
