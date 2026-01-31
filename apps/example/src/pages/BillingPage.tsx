import { useState } from 'react';
import { PlansCatalog, SubscriptionManagement } from '@ait-saas-sso/idp-sdk';
import { useAuth } from '@ait-saas-sso/idp-sdk';

// Mock product ID - en producción esto vendría del contexto
const MOCK_PRODUCT_ID = '00000000-0000-0000-0000-000000000002';
const MOCK_ORGANIZATION_ID = '00000000-0000-0000-0000-000000000001';

export const BillingPage = () => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<'catalog' | 'subscription'>('catalog');
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);

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
              productId={MOCK_PRODUCT_ID}
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
            <SubscriptionManagement
              organizationId={MOCK_ORGANIZATION_ID}
              onUpgrade={() => {
                console.log('Upgrade clicked');
                setActiveTab('catalog');
              }}
              onCancel={() => {
                console.log('Cancel subscription clicked');
                alert('Subscription cancellation would be processed here');
              }}
            />
          </div>
        )}
      </div>
    </div>
  );
};
