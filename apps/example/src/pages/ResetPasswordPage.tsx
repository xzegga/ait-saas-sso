import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { VerificationRequired, ResetPasswordForm, useVerifyOtp, useIDP } from '@ait-saas-sso/idp-sdk';

/**
 * Reset Password Page
 * 
 * Handles the complete password reset flow:
 * 1. User enters email (handled by ForgotPasswordPage)
 * 2. User verifies OTP code (this page - step 1)
 * 3. User sets new password (this page - step 2)
 * 4. Success message (this page - step 3)
 */
export const ResetPasswordPage = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { verifyOtp, loading: verifyingOtp, error: verifyError } = useVerifyOtp();
  const { config, supabase } = useIDP();
  
  // Get email from URL params or state
  const emailFromParams = searchParams.get('email');
  const [email, setEmail] = useState<string>(emailFromParams || '');
  const [step, setStep] = useState<'verify' | 'reset' | 'success'>('verify');
  const [verifiedEmail, setVerifiedEmail] = useState<string>('');

  const handleVerify = async (code: string) => {
    if (!email) {
      throw new Error('Email is required');
    }

    try {
      await verifyOtp(email, code, 'recovery', config.productId);
      setVerifiedEmail(email);
      setStep('reset');
    } catch (err) {
      throw err; // Let VerificationRequired handle the error
    }
  };

  const handleResend = async () => {
    if (!email) {
      throw new Error('Email is required');
    }

    // Resend OTP via Supabase - use resetPasswordForEmail instead of resend
    // because 'recovery' is not a valid type for resend()
    const redirectTo = typeof window !== 'undefined' 
      ? `${window.location.origin}/reset-password?email=${encodeURIComponent(email)}`
      : 'http://localhost:3000/reset-password';
    
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo,
    });

    if (error) {
      throw new Error(error.message);
    }
  };

  const handleResetSuccess = () => {
    setStep('success');
    // Redirect to login after a delay
    setTimeout(() => {
      navigate('/login');
    }, 3000);
  };

  if (!email) {
    // If no email, redirect to forgot password page
    navigate('/forgot-password');
    return null;
  }

  if (step === 'verify') {
    return (
      <div className="auth-page">
        <div className="auth-container">
          <h1>Reset Password</h1>
          <p className="auth-subtitle">Enter the verification code sent to your email</p>
          
          <VerificationRequired
            email={email}
            onVerify={handleVerify}
            onResend={handleResend}
            type="password_reset"
            loading={verifyingOtp}
            error={verifyError?.message || null}
          />
        </div>
      </div>
    );
  }

  if (step === 'reset') {
    return (
      <div className="auth-page">
        <div className="auth-container">
          <ResetPasswordForm
            email={verifiedEmail || email}
            onSuccess={handleResetSuccess}
            onError={(error) => console.error('Reset password error:', error)}
          />
        </div>
      </div>
    );
  }

  // Success step is handled by ResetPasswordForm component
  return null;
};
