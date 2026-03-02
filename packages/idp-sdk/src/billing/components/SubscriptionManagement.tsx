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

  const planName = subscription.product_plan?.plan?.name || 'Unknown';
  const status = subscription.status;
  const isTrial = status === 'trial';
  const trialEndsAt = subscription.trial_ends_at;

  return (
    <div className={`idp-subscription-management ${className}`}>
      <h3 className="idp-section-title">Current Subscription</h3>
      <div className="idp-subscription-info">
        <p className="idp-subscription-plan">
          <strong>Plan:</strong> {planName}
        </p>
        <p className="idp-subscription-status">
          <strong>Status:</strong> {status.charAt(0).toUpperCase() + status.slice(1)}
          {isTrial && (
            <span className="idp-trial-badge"> (Trial)</span>
          )}
        </p>
        {isTrial && trialEndsAt && (
          <p className="idp-subscription-trial">
            <strong>Trial ends:</strong> {new Date(trialEndsAt).toLocaleDateString()}
          </p>
        )}
        {!isTrial && subscription.current_period_end && (
          <p className="idp-subscription-period">
            <strong>Renews:</strong> {new Date(subscription.current_period_end).toLocaleDateString()}
          </p>
        )}
        {subscription.product && (
          <p className="idp-subscription-product">
            <strong>Product:</strong> {subscription.product.name}
          </p>
        )}
      </div>
      <div className="idp-subscription-actions">
        {onUpgrade && (
          <button onClick={onUpgrade} className="idp-button idp-button-primary">
            {isTrial ? 'Upgrade Now' : 'Upgrade Plan'}
          </button>
        )}
        {onCancel && !isTrial && (
          <button onClick={onCancel} className="idp-button idp-button-secondary">
            Cancel Subscription
          </button>
        )}
      </div>
    </div>
  );
};
