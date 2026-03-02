/**
 * Forgot Password Form Component
 * Handles password reset with OTP verification flow
 */

import React, { useState, FormEvent } from 'react';
import { toast } from 'sonner';
import { useForgotPassword } from '../hooks/useForgotPassword';
import { VerificationRequired } from './VerificationRequired';
import { logger } from '../../shared/logger';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Alert, AlertDescription } from '../../components/ui/alert';
import { AlertCircle } from 'lucide-react';

// Icon component to avoid React type conflicts between React 18 and 19
const Icon: React.FC<{ icon: typeof AlertCircle; className?: string }> = ({ 
  icon: IconComponent, 
  className 
}) => {
  const Component = IconComponent as any;
  return <Component className={className} />;
};

export interface ForgotPasswordFormProps {
  onSuccess?: (email: string) => void; // Called when OTP is sent, passes email for next step
  onError?: (error: Error) => void;
  className?: string;
}

export const ForgotPasswordForm: React.FC<ForgotPasswordFormProps> = ({
  onSuccess,
  onError,
  className = '',
}) => {
  const { sendResetEmail, resendCode, loading, error, success } = useForgotPassword();
  const [email, setEmail] = useState('');
  const [showVerification, setShowVerification] = useState(false);

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    try {
      await sendResetEmail(email);
      logger.info('Password reset OTP sent successfully');
      toast.success('Verification code sent to your email');
      setShowVerification(true);
      onSuccess?.(email);
    } catch (err: any) {
      logger.error('Forgot password form error', err);
      const message = err?.message ?? 'Error sending email';
      toast.error(message);
      onError?.(err);
    }
  };

  // Show verification step if OTP was sent
  if (showVerification && success) {
    return (
      <div className={`space-y-6 ${className}`}>
        <VerificationRequired
          email={email}
          onVerify={async (code: string) => {
            // Verification is handled by parent component (ResetPasswordPage)
            // This component just shows the verification UI
            throw new Error('Verification should be handled by parent component');
          }}
          onResend={async () => {
            try {
              await resendCode(email);
            } catch (err) {
              logger.error('Resend error', err);
              throw err;
            }
          }}
          type="password_reset"
          loading={loading}
          error={error?.message || null}
        />
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className={`space-y-4 ${className}`}>
      <div className="space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          disabled={loading}
          placeholder="Enter your email"
        />
        <p className="text-xs text-muted-foreground">
          We'll send you a verification code to reset your password.
        </p>
      </div>

      {error && (
        <Alert variant="destructive">
          <Icon icon={AlertCircle} className="h-4 w-4" />
          <AlertDescription>{error.message}</AlertDescription>
        </Alert>
      )}

      <Button
        type="submit"
        disabled={loading}
        className="w-full"
      >
        {loading ? 'Sending...' : 'Send Reset Link'}
      </Button>
    </form>
  );
};
