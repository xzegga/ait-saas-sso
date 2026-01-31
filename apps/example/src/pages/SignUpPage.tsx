import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { SignUpForm, useAvailablePlans } from '@ait-saas-sso/idp-sdk';

export const SignUpPage = () => {
  const navigate = useNavigate();
  const { plans, loading: plansLoading } = useAvailablePlans();
  const [currentStep, setCurrentStep] = useState<1 | 2>(1);

  return (
    <div className="auth-page">
      <div className={currentStep === 2 ? 'auth-container auth-container-wide' : 'auth-container'}>
        {currentStep === 1 && (
          <>
            <h1>Sign Up</h1>
            <p className="auth-subtitle">Create your account to get started</p>
          </>
        )}
        
        <SignUpForm
          availablePlans={plans}
          onStepChange={setCurrentStep}
          onSuccess={(data) => {
            console.log('Signup successful', data);
            navigate('/dashboard');
          }}
          onError={(error) => {
            console.error('Signup error:', error);
          }}
        />

        {currentStep === 1 && (
          <div className="auth-links">
            <p>
              Already have an account? <Link to="/login">Sign in</Link>
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
