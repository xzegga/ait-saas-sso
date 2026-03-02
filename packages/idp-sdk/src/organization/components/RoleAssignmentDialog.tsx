/**
 * Role Assignment Dialog Component (modular)
 */

import React, { useState, FormEvent } from 'react';
import { toast } from 'sonner';
import { useProductRoles } from '../hooks/useProductRoles';
import { ConfirmSaveDialog } from '../../shared/components/ConfirmSaveDialog';

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
  onError,
}: RoleAssignmentDialogProps) => {
  const { roles, loading: rolesLoading } = useProductRoles(productId);
  const [selectedRole, setSelectedRole] = useState('');
  const [showConfirm, setShowConfirm] = useState(false);

  const handleSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!selectedRole) return;
    setShowConfirm(true);
  };

  const handleConfirmAssign = async () => {
    try {
      // TODO: assign role via API when backend is available
      onSuccess?.();
      onClose();
      toast.success('Role assigned successfully');
    } catch (err: any) {
      const message = err instanceof Error ? err.message : 'Error assigning role';
      toast.error(message);
      onError?.(err instanceof Error ? err : new Error(message));
    }
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
      <ConfirmSaveDialog
        open={showConfirm}
        onOpenChange={setShowConfirm}
        title="Confirm assignment"
        description="Do you want to assign this role to the member?"
        confirmLabel="Assign role"
        cancelLabel="Cancel"
        onConfirm={handleConfirmAssign}
        loading={false}
      />
    </div>
  );
};
