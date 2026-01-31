/**
 * Subscription Management Component (modular)
 */

import React from 'react';
import { useCurrentSubscription } from '../hooks/useCurrentSubscription';

export interface SubscriptionManagementProps {
  organizationId?: string;
  onUpgrade?: () => void;
  onCancel?: () => void;
  className?: string;
}

export const SubscriptionManagement: React.FC<SubscriptionManagementProps> = ({
  organizationId,
  onUpgrade,
  onCancel,
  className = '',
}: SubscriptionManagementProps) => {
  const { subscription, loading, error } = useCurrentSubscription(organizationId);

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading subscription...</div>;
  }

  if (error) {
    return <div className={`idp-error ${className}`}>{error.message}</div>;
  }

  if (!subscription) {
    return <div className={`idp-empty-state ${className}`}>No active subscription</div>;
  }

  return (
    <div className={`idp-subscription-management ${className}`}>
      <h3 className="idp-section-title">Current Subscription</h3>
      <div className="idp-subscription-info">
        <p className="idp-subscription-plan">
          Plan: {subscription.product_plan?.plan?.name || 'Unknown'}
        </p>
        <p className="idp-subscription-status">Status: {subscription.status}</p>
        {subscription.current_period_end && (
          <p className="idp-subscription-period">
            Renews: {new Date(subscription.current_period_end).toLocaleDateString()}
          </p>
        )}
      </div>
      <div className="idp-subscription-actions">
        {onUpgrade && (
          <button onClick={onUpgrade} className="idp-button idp-button-primary">
            Upgrade Plan
          </button>
        )}
        {onCancel && (
          <button onClick={onCancel} className="idp-button idp-button-secondary">
            Cancel Subscription
          </button>
        )}
      </div>
    </div>
  );
};
