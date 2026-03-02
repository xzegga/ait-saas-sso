/**
 * Verification Required Component
 * 
 * Displays a verification screen where users enter their OTP code
 * Uses the same design patterns as LoginForm and SignUpForm
 */

import React, { useState, useEffect } from 'react';
import { OTPInput } from './OTPInput';
import { Button } from '../../components/ui/button';
import { Label } from '../../components/ui/label';
import { Alert, AlertDescription } from '../../components/ui/alert';
import { AlertCircle } from 'lucide-react';
import { logger } from '../../shared/logger';
import { cn } from '@/lib/utils';

// Icon component to avoid React type conflicts between React 18 and 19
const Icon: React.FC<{ icon: typeof AlertCircle; className?: string }> = ({ 
  icon: IconComponent, 
  className 
}) => {
  const Component = IconComponent as any;
  return <Component className={className} />;
};

export interface VerificationRequiredProps {
  email: string;
  onVerify: (code: string) => Promise<void>;
  onResend?: () => Promise<void>;
  type?: 'signup' | 'password_reset';
  loading?: boolean;
  error?: string | null;
  className?: string;
}

export const VerificationRequired: React.FC<VerificationRequiredProps> = ({
  email,
  onVerify,
  onResend,
  type = 'signup',
  loading = false,
  error = null,
  className = '',
}) => {
  const [otp, setOtp] = useState('');
  const [isResending, setIsResending] = useState(false);
  const [resendMessage, setResendMessage] = useState<string | null>(null);
  const [isVerifying, setIsVerifying] = useState(false);

  useEffect(() => {
    // Auto-verify when OTP is complete (6 digits)
    if (otp.length === 6 && !isVerifying && !loading) {
      handleVerify();
    }
  }, [otp]);

  const handleVerify = async () => {
    if (otp.length !== 6 || isVerifying || loading) {
      return;
    }

    setIsVerifying(true);
    try {
      await onVerify(otp);
    } catch (err) {
      logger.error('Verification error', err);
      // Error is handled by parent component
    } finally {
      setIsVerifying(false);
    }
  };

  const handleResend = async () => {
    if (isResending || !onResend) {
      return;
    }

    setIsResending(true);
    setResendMessage(null);
    try {
      await onResend();
      setResendMessage('A new verification code has been sent to your email.');
      setTimeout(() => setResendMessage(null), 5000);
    } catch (err) {
      logger.error('Resend error', err);
      setResendMessage('Failed to resend code. Please try again.');
    } finally {
      setIsResending(false);
    }
  };

  const instructionText =
    type === 'password_reset'
      ? 'Enter the code to continue with your password reset'
      : 'Enter the code to verify your account';

  const isDisabled = loading || isVerifying || isResending;

  return (
    <div className={cn('idp-space-y-4', className)}>
      {/* Header */}
      <div className="idp-text-center idp-space-y-2">
        <h2 className="idp-text-2xl idp-font-bold idp-text-foreground">
          Verification Required
        </h2>
        <p className="idp-text-sm idp-text-muted-foreground">
          Enter the verification code sent to your email
        </p>
      </div>

      {/* Success message for resend */}
      {resendMessage && (
        <Alert variant="default" className="idp-bg-blue-50 dark:idp-bg-blue-900/20 idp-border-blue-200 dark:idp-border-blue-800">
          <AlertDescription className="idp-text-sm idp-text-blue-800 dark:idp-text-blue-200">
            {resendMessage}
          </AlertDescription>
        </Alert>
      )}

      {/* Email display */}
      <div className="idp-text-center idp-space-y-1">
        <p className="idp-text-sm idp-text-muted-foreground">
          We've sent a verification code to
        </p>
        <p className="idp-text-sm idp-font-semibold idp-text-foreground">
          {email}
        </p>
        <p className="idp-text-sm idp-text-muted-foreground idp-mt-2">
          {instructionText}
        </p>
      </div>

      {/* OTP Input */}
      <div className="idp-space-y-2">
        <Label htmlFor="otp">Verification Code</Label>
        <OTPInput
          value={otp}
          onChange={setOtp}
          disabled={isDisabled}
          error={!!error}
          autoFocus={true}
        />
        {error && (
          <Alert variant="destructive" className="idp-mt-2">
            <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
            <AlertDescription className="idp-text-sm">{error}</AlertDescription>
          </Alert>
        )}
      </div>

      {/* Verify Button */}
      {type === 'password_reset' ? (
        <Button
          onClick={handleVerify}
          disabled={otp.length !== 6 || isDisabled}
          className="idp-w-full"
        >
          {isVerifying ? 'Verifying...' : 'Continue Password Reset'}
        </Button>
      ) : (
        <Button
          onClick={handleVerify}
          disabled={otp.length !== 6 || isDisabled}
          className="idp-w-full"
        >
          {isVerifying ? 'Verifying...' : loading ? 'Processing...' : 'Verify Email'}
        </Button>
      )}

      {/* Resend Code */}
      {onResend && (
        <div className="idp-text-center">
          <p className="idp-text-sm idp-text-muted-foreground">
            Didn't receive the code?{' '}
            <button
              type="button"
              onClick={handleResend}
              disabled={isResending || isDisabled}
              className="idp-text-blue-600 hover:idp-text-blue-700 dark:idp-text-blue-400 dark:hover:idp-text-blue-300 idp-font-medium disabled:idp-opacity-50 disabled:idp-cursor-not-allowed idp-transition-colors"
            >
              {isResending ? 'Sending...' : 'Resend'}
            </button>
          </p>
        </div>
      )}
    </div>
  );
};
