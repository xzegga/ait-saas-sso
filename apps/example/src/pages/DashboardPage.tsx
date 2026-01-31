import { useAuth } from '@ait-saas-sso/idp-sdk';
import { PermissionGate, FeatureFlag } from '@ait-saas-sso/idp-sdk';

export const DashboardPage = () => {
  const { user } = useAuth();

  return (
    <div className="dashboard-page">
      <div className="page-header">
        <h1>Dashboard</h1>
        <p>Welcome back, {user?.email || 'User'}!</p>
      </div>

      <div className="dashboard-content">
        <div className="dashboard-grid">
          <div className="dashboard-card">
            <h3>Quick Stats</h3>
            <div className="stats-grid">
              <div className="stat-item">
                <div className="stat-value">12</div>
                <div className="stat-label">Active Projects</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">48</div>
                <div className="stat-label">Team Members</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">$2,450</div>
                <div className="stat-label">Monthly Revenue</div>
              </div>
            </div>
          </div>

          <div className="dashboard-card">
            <h3>Recent Activity</h3>
            <ul className="activity-list">
              <li>New member joined the organization</li>
              <li>Subscription plan updated</li>
              <li>Payment method added</li>
              <li>Profile information updated</li>
            </ul>
          </div>
        </div>

        <div className="dashboard-card">
          <h3>Permission Examples</h3>
          <div className="permission-examples">
            <PermissionGate permission="admin:read">
              <div className="permission-badge success">
                ✓ You have admin:read permission
              </div>
            </PermissionGate>
            
            <PermissionGate permission="admin:write" fallback={<div className="permission-badge">✗ No admin:write permission</div>}>
              <div className="permission-badge success">
                ✓ You have admin:write permission
              </div>
            </PermissionGate>

            <FeatureFlag feature="advanced-analytics">
              <div className="permission-badge success">
                ✓ Advanced Analytics feature enabled
              </div>
            </FeatureFlag>

            <FeatureFlag feature="beta-features" fallback={<div className="permission-badge">✗ Beta Features not available</div>}>
              <div className="permission-badge success">
                ✓ Beta Features enabled
              </div>
            </FeatureFlag>
          </div>
        </div>
      </div>
    </div>
  );
};
