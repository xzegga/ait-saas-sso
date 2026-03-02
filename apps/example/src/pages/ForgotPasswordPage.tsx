import { useNavigate } from 'react-router-dom';
import { Link } from 'react-router-dom';
import { ForgotPasswordForm } from '@ait-saas-sso/idp-sdk';

export const ForgotPasswordPage = () => {
  const navigate = useNavigate();

  const handleSuccess = (email: string) => {
    // Navigate to reset password page with email
    navigate(`/reset-password?email=${encodeURIComponent(email)}`);
  };

  return (
    <div className="auth-page">
      <div className="auth-container">
        <h1>Reset Password</h1>
        <p className="auth-subtitle">Enter your email to receive a password reset code</p>
        
        <ForgotPasswordForm
          onSuccess={handleSuccess}
          onError={(error) => console.error('Error:', error)}
        />

        <div className="auth-links">
          <Link to="/login">Remember your password? Sign in</Link>
        </div>
      </div>
    </div>
  );
};
