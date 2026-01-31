/**
 * Forgot Password Form Component (modular, no page wrapper)
 */

import React, { useState, FormEvent } from 'react';
import { useForgotPassword } from '../hooks/useForgotPassword';
import { logger } from '../../shared/logger';

export interface ForgotPasswordFormProps {
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
}

export const ForgotPasswordForm: React.FC<ForgotPasswordFormProps> = ({
  onSuccess,
  onError,
  className = '',
}: ForgotPasswordFormProps) => {
  const { sendResetEmail, loading, error, success } = useForgotPassword();
  const [email, setEmail] = useState('');

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    try {
      await sendResetEmail(email);
      logger.info('Password reset email sent successfully');
      onSuccess?.();
    } catch (err: any) {
      logger.error('Forgot password form error', err);
      onError?.(err);
    }
  };

  if (success) {
    return (
      <div className={`idp-forgot-password-success ${className}`}>
        <p className="idp-success-message">
          Password reset email sent! Please check your inbox.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className={`idp-forgot-password-form ${className}`}>
      <div className="idp-form-group">
        <label htmlFor="email" className="idp-label">
          Email
        </label>
        <input
          id="email"
          type="email"
          value={email}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
          required
          disabled={loading}
          className="idp-input"
          placeholder="Enter your email"
        />
        <p className="idp-help-text">
          We'll send you a link to reset your password.
        </p>
      </div>

      {error && (
        <div className="idp-error-message" role="alert">
          {error.message}
        </div>
      )}

      <button
        type="submit"
        disabled={loading}
        className="idp-button idp-button-primary"
      >
        {loading ? 'Sending...' : 'Send Reset Link'}
      </button>
    </form>
  );
};
