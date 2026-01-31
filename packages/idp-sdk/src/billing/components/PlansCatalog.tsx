/**
 * Plans Catalog Component (modular)
 */

import React from 'react';
import { useProductPlans } from '../hooks/useProductPlans';
import { useBillingIntervals, type BillingIntervalData } from '../hooks/useBillingIntervals';

export interface PlansCatalogProps {
  productId: string;
  currentPlanId?: string;
  onSelectPlan?: (planId: string, interval: string) => void;
  className?: string;
}

export const PlansCatalog: React.FC<PlansCatalogProps> = ({
  productId,
  currentPlanId,
  onSelectPlan,
  className = '',
}: PlansCatalogProps) => {
  const { plans, loading, error } = useProductPlans(productId);
  const { intervals } = useBillingIntervals();

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading plans...</div>;
  }

  if (error) {
    return <div className={`idp-error ${className}`}>{error.message}</div>;
  }

  return (
    <div className={`idp-plans-catalog ${className}`}>
      <h3 className="idp-catalog-title">Choose a Plan</h3>
      <div className="idp-plans-grid">
        {plans.map((plan) => (
          <div
            key={plan.id}
            className={`idp-plan-card ${plan.id === currentPlanId ? 'idp-plan-current' : ''}`}
          >
            <h4 className="idp-plan-name">{plan.plan?.name || 'Plan'}</h4>
            <p className="idp-plan-description">{plan.plan?.description || ''}</p>
            
            {intervals.map((interval) => {
              const price = plan.prices_by_interval?.find(
                (p) => p.billing_interval === interval.key
              );
              
              return price ? (
                <div key={interval.key} className="idp-plan-pricing">
                  <span className="idp-plan-price">${price.price}</span>
                  <span className="idp-plan-interval">/{interval.label}</span>
                  <button
                    onClick={() => onSelectPlan?.(plan.id, interval.key)}
                    className="idp-button idp-button-primary"
                    disabled={plan.id === currentPlanId}
                  >
                    {plan.id === currentPlanId ? 'Current Plan' : 'Subscribe'}
                  </button>
                </div>
              ) : null;
            })}
          </div>
        ))}
      </div>
    </div>
  );
};
