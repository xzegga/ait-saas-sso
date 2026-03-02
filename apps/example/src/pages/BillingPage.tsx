import { useState, useMemo } from 'react';
import { logger, PlansCatalog, SubscriptionManagement, useIDP } from '@ait-saas-sso/idp-sdk';
import { useAuth } from '@ait-saas-sso/idp-sdk';
import { parseJWT, getOrganizationId } from '@ait-saas-sso/idp-sdk';

export const BillingPage = () => {
  const { session } = useAuth();
  const { config } = useIDP();
  const [activeTab, setActiveTab] = useState<'catalog' | 'subscription'>('catalog');
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);
    // Get real organization ID from JWT
  const organizationId = useMemo(() => {
    
    if (session?.access_token) {
      const payload = parseJWT(session.access_token);
      return getOrganizationId(payload);
    }
    return config.organizationId || undefined;
  }, [session, config.organizationId]);

  // Get real product ID from config
  const productId = config.productId;

  // Show error if required values are missing
  if (!productId) {
    return (
      <div className="billing-page">
        <div className="error-message">
          <p>Product ID is not configured. Please check your environment variables.</p>
        </div>
      </div>
    );
  }


  return (
    <div className="billing-page">
      <div className="page-header">
        <h1>Billing & Subscriptions</h1>
        <p>Manage your plans and subscriptions</p>
      </div>

      <div className="billing-content">
        <div className="billing-tabs">
          <button
            className={activeTab === 'catalog' ? 'active' : ''}
            onClick={() => setActiveTab('catalog')}
          >
            Plans Catalog
          </button>
          <button
            className={activeTab === 'subscription' ? 'active' : ''}
            onClick={() => setActiveTab('subscription')}
          >
            My Subscription
          </button>
        </div>

        {activeTab === 'catalog' ? (
          <div className="billing-section">
            <h2>Available Plans</h2>
            <PlansCatalog
              productId={productId}
              currentPlanId={selectedPlan || undefined}
              onSelectPlan={(planId, interval) => {
                console.log('Selected plan:', planId, 'Interval:', interval);
                setSelectedPlan(planId);
                alert(`Selected plan ${planId} with ${interval} billing`);
              }}
            />
          </div>
        ) : (
          <div className="billing-section">
            <h2>Current Subscription</h2>
            {organizationId ? (
              <SubscriptionManagement
                organizationId={organizationId}
                onUpgrade={() => {
                  console.log('Upgrade clicked');
                  setActiveTab('catalog');
                }}
                onCancel={() => {
                  console.log('Cancel subscription clicked');
                  alert('Subscription cancellation would be processed here');
                }}
              />
            ) : (
              <div className="error-message">
                <p>Organization ID not found. Please ensure you are logged in and have an active organization.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
