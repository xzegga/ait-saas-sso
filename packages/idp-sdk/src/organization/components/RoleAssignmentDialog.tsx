/**
 * Role Assignment Dialog Component (modular)
 */

import React, { useState, FormEvent } from 'react';
import { useProductRoles } from '../hooks/useProductRoles';

export interface RoleAssignmentDialogProps {
  productId: string;
  memberId: string;
  onClose: () => void;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
}

export const RoleAssignmentDialog: React.FC<RoleAssignmentDialogProps> = ({
  productId,
  onClose,
  onSuccess,
}: RoleAssignmentDialogProps) => {
  const { roles, loading: rolesLoading } = useProductRoles(productId);
  const [selectedRole, setSelectedRole] = useState('');

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    // Implementation would assign role via API
    onSuccess?.();
    onClose();
  };

  return (
    <div className="idp-dialog-overlay" onClick={onClose}>
      <div className="idp-dialog" onClick={(e: React.MouseEvent<HTMLDivElement>) => e.stopPropagation()}>
        <h3 className="idp-dialog-title">Assign Role</h3>
        
        <form onSubmit={handleSubmit}>
          <div className="idp-form-group">
            <label htmlFor="role" className="idp-label">
              Role
            </label>
            <select
              id="role"
              value={selectedRole}
              onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setSelectedRole(e.target.value)}
              disabled={rolesLoading}
              className="idp-select"
            >
              <option value="">Select a role</option>
              {roles.map((role) => (
                <option key={role.id} value={role.role_name}>
                  {role.role_name}
                </option>
              ))}
            </select>
          </div>

          <div className="idp-dialog-actions">
            <button
              type="button"
              onClick={onClose}
              disabled={rolesLoading}
              className="idp-button idp-button-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!selectedRole}
              className="idp-button idp-button-primary"
            >
              Assign Role
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
