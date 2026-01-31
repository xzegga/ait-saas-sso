import { Link } from 'react-router-dom';
import { useAuth } from '@ait-saas-sso/idp-sdk';

export const HomePage = () => {
  const { user } = useAuth();

  return (
    <div className="home-page">
      <div className="home-container">
        <h1>IDP SDK Demo</h1>
        <p className="home-subtitle">
          Demo completo del SDK de Identity Provider
        </p>
        
        {user ? (
          <div className="home-actions">
            <Link to="/dashboard" className="home-button primary">
              Go to Dashboard
            </Link>
          </div>
        ) : (
          <div className="home-actions">
            <Link to="/login" className="home-button primary">
              Sign In
            </Link>
          </div>
        )}

        <div className="home-features">
          <h2>Features Demo</h2>
          <div className="features-grid">
            <div className="feature-card">
              <h3>Authentication</h3>
              <p>Login, logout, password recovery</p>
            </div>
            <div className="feature-card">
              <h3>Profile Management</h3>
              <p>User and organization profiles</p>
            </div>
            <div className="feature-card">
              <h3>Organization</h3>
              <p>Member management and invitations</p>
            </div>
            <div className="feature-card">
              <h3>Billing</h3>
              <p>Plans, subscriptions, and payments</p>
            </div>
            <div className="feature-card">
              <h3>Permissions</h3>
              <p>Access control and authorization</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
