import { Link } from 'react-router-dom';
import { ForgotPasswordForm } from '@ait-saas-sso/idp-sdk';

export const ForgotPasswordPage = () => {
  return (
    <div className="auth-page">
      <div className="auth-container">
        <h1>Reset Password</h1>
        <p className="auth-subtitle">Enter your email to receive a password reset link</p>
        
        <ForgotPasswordForm
          onSuccess={() => console.log('Password reset email sent')}
          onError={(error) => console.error('Error:', error)}
        />

        <div className="auth-links">
          <Link to="/login">Back to Sign In</Link>
        </div>
      </div>
    </div>
  );
};
