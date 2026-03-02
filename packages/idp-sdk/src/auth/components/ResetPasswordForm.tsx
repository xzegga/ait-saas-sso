/**
 * Reset Password Form Component
 * Handles password reset after OTP verification
 */

import React, { useState, FormEvent } from 'react';
import { toast } from 'sonner';
import { useResetPassword } from '../hooks/useResetPassword';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Alert, AlertDescription } from '../../components/ui/alert';
import { AlertCircle } from 'lucide-react';
import { PasswordResetSuccess } from './PasswordResetSuccess';

// Icon component to avoid React type conflicts between React 18 and 19
const Icon: React.FC<{ icon: typeof AlertCircle; className?: string }> = ({ 
  icon: IconComponent, 
  className 
}) => {
  const Component = IconComponent as any;
  return <Component className={className} />;
};

export interface ResetPasswordFormProps {
  email: string;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
}

export const ResetPasswordForm: React.FC<ResetPasswordFormProps> = ({
  email,
  onSuccess,
  onError,
  className = '',
}) => {
  const { resetPassword, loading, error } = useResetPassword();
  const { config } = useIDP();
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showSuccess, setShowSuccess] = useState(false);

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    // Validate passwords match
    if (newPassword !== confirmPassword) {
      toast.error('Passwords do not match');
      onError?.(new Error('Passwords do not match'));
      return;
    }

    try {
      await resetPassword(newPassword, confirmPassword, config.productId);
      logger.info('Password reset successfully');
      toast.success('Password reset successfully');
      setShowSuccess(true);
      onSuccess?.();
    } catch (err: any) {
      logger.error('Reset password form error', err);
      const message = err?.message ?? 'Error resetting password';
      toast.error(message);
      onError?.(err);
    }
  };

  if (showSuccess) {
    return (
      <PasswordResetSuccess
        onSignIn={onSuccess}
        className={className}
      />
    );
  }

  return (
    <form onSubmit={handleSubmit} className={`space-y-4 ${className}`}>
      <div className="space-y-2">
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
          Set New Password
        </h2>
        <p className="text-sm text-gray-600 dark:text-gray-400">
          Create a new password for your account
        </p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="newPassword">New Password</Label>
        <Input
          id="newPassword"
          type="password"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          required
          disabled={loading}
          placeholder="Enter new password"
          minLength={6}
        />
        <p className="text-xs text-muted-foreground">
          Password must be at least 6 characters
        </p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="confirmNewPassword">Confirm New Password</Label>
        <Input
          id="confirmNewPassword"
          type="password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          required
          disabled={loading}
          placeholder="Confirm new password"
          minLength={6}
        />
        {confirmPassword && newPassword !== confirmPassword && (
          <p className="text-xs text-red-600 dark:text-red-400">
            Passwords do not match
          </p>
        )}
      </div>

      {error && (
        <Alert variant="destructive">
          <Icon icon={AlertCircle} className="h-4 w-4" />
          <AlertDescription>{error.message}</AlertDescription>
        </Alert>
      )}

      <Button
        type="submit"
        disabled={loading || newPassword !== confirmPassword || newPassword.length < 6}
        className="w-full"
      >
        {loading ? 'Updating...' : 'Update password'}
      </Button>
    </form>
  );
};
