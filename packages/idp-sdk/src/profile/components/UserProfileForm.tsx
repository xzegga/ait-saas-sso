/**
 * User Profile Form Component (modular)
 */

import React, { useState, FormEvent, useEffect } from 'react';
import { useUserProfile } from '../hooks/useUserProfile';
import { useChangePassword } from '../hooks/useChangePassword';

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

  useEffect(() => {
    if (profile) {
      setFullName(profile.full_name || '');
      setEmail(profile.email || '');
    }
  }, [profile]);

  const handleProfileSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    try {
      await updateProfile({ full_name: fullName });
      onSuccess?.();
    } catch (err: any) {
      onError?.(err);
    }
  };

  const handlePasswordSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    if (newPassword !== confirmPassword) {
      onError?.(new Error('Passwords do not match'));
      return;
    }

    try {
      await changePassword(newPassword);
      setNewPassword('');
      setConfirmPassword('');
      onSuccess?.();
    } catch (err: any) {
      onError?.(err);
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
    </div>
  );
};
