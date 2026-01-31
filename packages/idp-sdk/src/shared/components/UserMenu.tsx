/**
 * User Menu Component (modular)
 */

import React, { useState } from 'react';
import { useAuth } from '../../providers/AuthProvider';
import { useUserProfile } from '../../profile/hooks/useUserProfile';
import { useLogout } from '../../auth/hooks/useLogout';

export interface UserMenuProps {
  onLogout?: () => void;
  className?: string;
}

export const UserMenu: React.FC<UserMenuProps> = ({
  onLogout,
  className = '',
}: UserMenuProps) => {
  const { user } = useAuth();
  const { profile } = useUserProfile();
  const { logout } = useLogout();
  const [isOpen, setIsOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    onLogout?.();
  };

  const displayName = profile?.full_name || user?.email || 'User';

  return (
    <div className={`idp-user-menu ${className}`}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="idp-user-menu-button"
      >
        {displayName}
      </button>
      {isOpen && (
        <div className="idp-user-menu-dropdown">
          <div className="idp-user-menu-item">{displayName}</div>
          <button
            onClick={handleLogout}
            className="idp-user-menu-item idp-user-menu-logout"
          >
            Logout
          </button>
        </div>
      )}
    </div>
  );
};
