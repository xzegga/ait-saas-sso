/**
 * User Profile Form Component (modular)
 */

import React, { useState, FormEvent, useEffect } from 'react';
import { toast } from 'sonner';
import { useUserProfile } from '../hooks/useUserProfile';
import { useChangePassword } from '../hooks/useChangePassword';
import { ConfirmSaveDialog } from '../../shared/components/ConfirmSaveDialog';

export interface UserProfileFormProps {
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
}

export const UserProfileForm: React.FC<UserProfileFormProps> = ({
  onSuccess,
  onError,
  className = '',
}: UserProfileFormProps) => {
  const { profile, loading, error, updateProfile, updating } = useUserProfile();
  const { changePassword, loading: changingPassword } = useChangePassword();
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [confirmState, setConfirmState] = useState<'profile' | 'password' | null>(null);

  useEffect(() => {
    if (profile) {
      setFullName(profile.full_name || '');
      setEmail(profile.email || '');
    }
  }, [profile]);

  const handleProfileSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setConfirmState('profile');
  };

  const handlePasswordSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      toast.error('Passwords do not match');
      onError?.(new Error('Passwords do not match'));
      return;
    }
    setConfirmState('password');
  };

  const handleConfirmProfile = async () => {
    try {
      await updateProfile({ full_name: fullName });
      toast.success('Profile updated successfully');
      onSuccess?.();
    } catch (err: any) {
      const message = err instanceof Error ? err.message : 'Error al guardar';
      const msg = err instanceof Error ? err.message : 'Error saving profile';
      toast.error(msg);
      onError?.(err instanceof Error ? err : new Error(msg));
    }
  };

  const handleConfirmPassword = async () => {
    try {
      await changePassword(newPassword);
      setNewPassword('');
      setConfirmPassword('');
      toast.success('Password updated successfully');
      onSuccess?.();
    } catch (err: any) {
      const message = err instanceof Error ? err.message : 'Error al cambiar contraseña';
      const msg = err instanceof Error ? err.message : 'Error changing password';
      toast.error(msg);
      onError?.(err instanceof Error ? err : new Error(msg));
    }
  };

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading profile...</div>;
  }

  return (
    <div className={`idp-user-profile-form ${className}`}>
      <form onSubmit={handleProfileSubmit} className="idp-form-section">
        <h3 className="idp-form-title">Profile Information</h3>
        
        <div className="idp-form-group">
          <label htmlFor="fullName" className="idp-label">
            Full Name
          </label>
          <input
            id="fullName"
            type="text"
            value={fullName}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFullName(e.target.value)}
            disabled={updating}
            className="idp-input"
            placeholder="Enter your full name"
          />
        </div>

        <div className="idp-form-group">
          <label htmlFor="email" className="idp-label">
            Email
          </label>
          <input
            id="email"
            type="email"
            value={email}
            disabled
            className="idp-input idp-input-disabled"
          />
          <p className="idp-help-text">Email cannot be changed</p>
        </div>

        {error && (
          <div className="idp-error-message" role="alert">
            {error.message}
          </div>
        )}

        <button
          type="submit"
          disabled={updating}
          className="idp-button idp-button-primary"
        >
          {updating ? 'Saving...' : 'Save Changes'}
        </button>
      </form>

      <form onSubmit={handlePasswordSubmit} className="idp-form-section">
        <h3 className="idp-form-title">Change Password</h3>
        
        <div className="idp-form-group">
          <label htmlFor="newPassword" className="idp-label">
            New Password
          </label>
          <input
            id="newPassword"
            type="password"
            value={newPassword}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setNewPassword(e.target.value)}
            disabled={changingPassword}
            className="idp-input"
            placeholder="Enter new password"
            minLength={6}
          />
        </div>

        <div className="idp-form-group">
          <label htmlFor="confirmPassword" className="idp-label">
            Confirm Password
          </label>
          <input
            id="confirmPassword"
            type="password"
            value={confirmPassword}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setConfirmPassword(e.target.value)}
            disabled={changingPassword}
            className="idp-input"
            placeholder="Confirm new password"
            minLength={6}
          />
        </div>

        <button
          type="submit"
          disabled={changingPassword || !newPassword || !confirmPassword}
          className="idp-button idp-button-primary"
        >
          {changingPassword ? 'Changing...' : 'Change Password'}
        </button>
      </form>
      {confirmState === 'profile' && (
        <ConfirmSaveDialog
          open={true}
          onOpenChange={(open) => !open && setConfirmState(null)}
          title="Confirm save"
          description="Do you want to save your profile changes?"
          confirmLabel="Save"
          cancelLabel="Cancel"
          onConfirm={handleConfirmProfile}
          loading={updating}
        />
      )}
      {confirmState === 'password' && (
        <ConfirmSaveDialog
          open={true}
          onOpenChange={(open) => !open && setConfirmState(null)}
          title="Confirm password change"
          description="Do you want to change your password?"
          confirmLabel="Change password"
          cancelLabel="Cancel"
          onConfirm={handleConfirmPassword}
          loading={changingPassword}
        />
      )}
    </div>
  );
};
