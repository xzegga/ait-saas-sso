/**
 * Login Form Component (modular, no page wrapper)
 * Uses shadcn/ui components with embedded styles
 */

import React, { useState, FormEvent } from 'react';
import { useLogin } from '../hooks/useLogin';
import { useIDP } from '../../providers/IDPProvider';
import { logger } from '../../shared/logger';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Alert, AlertDescription, AlertTitle } from '../../components/ui/alert';
import { AlertCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

// Icon component to avoid React type conflicts between React 18 and 19
const Icon: React.FC<{ icon: typeof AlertCircle; className?: string }> = ({ icon: IconComponent, className }) => {
  const Component = IconComponent as any;
  return <Component className={className} />;
};

export interface LoginFormProps {
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
}

export const LoginForm: React.FC<LoginFormProps> = ({
  onSuccess,
  onError,
  className = '',
}: LoginFormProps) => {
  const { login, loading, error } = useLogin();
  const { validationError, isValidating, config } = useIDP();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // Check if client_secret validation failed
  const hasValidationError = !!(validationError && config.clientSecret);
  const isDisabled = hasValidationError || isValidating || loading;

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    // Prevent submission if validation failed
    if (hasValidationError) {
      return;
    }
    
    try {
      await login({ email, password });
      logger.info('Login form submitted successfully');
      onSuccess?.();
    } catch (err: any) {
      logger.error('Login form error', err);
      onError?.(err);
    }
  };

  return (
    <form onSubmit={handleSubmit} className={cn('idp-space-y-4', className)}>
      {/* Client Secret Validation Error - shown above form */}
      {hasValidationError && (
        <Alert variant="warning" className="idp-mb-6">
          <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
          <AlertTitle>Configuration Error</AlertTitle>
          <AlertDescription>
            <p className="idp-mb-2">{validationError.message}</p>
            <p className="idp-text-xs idp-opacity-80">
              Please check your VITE_CLIENT_SECRET and VITE_PRODUCT_ID environment variables.
            </p>
          </AlertDescription>
        </Alert>
      )}

      <div className="idp-space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          type="email"
          value={email}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
          required
          disabled={isDisabled}
          placeholder="Enter your email"
        />
      </div>

      <div className="idp-space-y-2">
        <Label htmlFor="password">Password</Label>
        <Input
          id="password"
          type="password"
          value={password}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPassword(e.target.value)}
          required
          disabled={isDisabled}
          placeholder="Enter your password"
        />
      </div>

      {/* Login Error - shown below form fields */}
      {error && !hasValidationError && (
        <Alert variant="destructive">
          <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
          <AlertDescription>{error.message}</AlertDescription>
        </Alert>
      )}

      <Button
        type="submit"
        disabled={isDisabled}
        className="idp-w-full"
      >
        {isValidating ? 'Validating...' : loading ? 'Signing in...' : 'Sign In'}
      </Button>
    </form>
  );
};
