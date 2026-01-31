import { useNavigate, Link } from 'react-router-dom';
import { LoginForm } from '@ait-saas-sso/idp-sdk';

export const LoginPage = () => {
  const navigate = useNavigate();

  return (
    <div className="auth-page">
      <div className="auth-container">
        <h1>Sign In</h1>
        <p className="auth-subtitle">Sign in to your account</p>
        
        <LoginForm
          onSuccess={() => navigate('/dashboard')}
          onError={(error) => console.error('Login error:', error)}
        />

        <div className="auth-links">
          <Link to="/forgot-password">Forgot your password?</Link>
          <p>
            Don't have an account? <Link to="/signup">Sign up</Link>
          </p>
        </div>
      </div>
    </div>
  );
};
