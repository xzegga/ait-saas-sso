/**
 * Password Reset Success Component
 * 
 * Displays a success message after password reset with option to sign in
 */

import React from 'react';
import { Button } from '../../components/ui/button';
import { CheckCircle2 } from 'lucide-react';

// Icon component to avoid React type conflicts between React 18 and 19
const Icon: React.FC<{ icon: typeof CheckCircle2; className?: string }> = ({ 
  icon: IconComponent, 
  className 
}) => {
  const Component = IconComponent as any;
  return <Component className={className} />;
};

export interface PasswordResetSuccessProps {
  onSignIn?: () => void;
  className?: string;
}

export const PasswordResetSuccess: React.FC<PasswordResetSuccessProps> = ({
  onSignIn,
  className = '',
}) => {
  return (
    <div className={`max-w-md mx-auto space-y-6 text-center ${className}`}>
      <div className="space-y-4">
        <div className="flex justify-center">
          <div className="rounded-full bg-green-100 dark:bg-green-900/20 p-3">
            <Icon icon={CheckCircle2} className="h-12 w-12 text-green-600 dark:text-green-400" />
          </div>
        </div>
        
        <div className="space-y-2">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
            Password Updated
          </h2>
          <p className="text-gray-600 dark:text-gray-400">
            Your password has been successfully updated. You can now sign in with your new password.
          </p>
        </div>
      </div>

      {onSignIn && (
        <Button
          onClick={onSignIn}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white"
          size="lg"
        >
          Sign In
        </Button>
      )}
    </div>
  );
};
