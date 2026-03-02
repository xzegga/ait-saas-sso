/**
 * Invite Member Dialog Component (modular)
 */

import React, { useState, FormEvent } from 'react';
import { toast } from 'sonner';
import { useInviteMember } from '../hooks/useInviteMember';
import { ConfirmSaveDialog } from '../../shared/components/ConfirmSaveDialog';

export interface InviteMemberDialogProps {
  organizationId: string;
  onClose: () => void;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
}

export const InviteMemberDialog: React.FC<InviteMemberDialogProps> = ({
  organizationId,
  onClose,
  onSuccess,
  onError,
}: InviteMemberDialogProps) => {
  const { inviteMember, loading, error } = useInviteMember(organizationId);
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('member');
  const [showConfirm, setShowConfirm] = useState(false);

  const handleSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setShowConfirm(true);
  };

  const handleConfirmInvite = async () => {
    try {
      await inviteMember({ email, role });
      toast.success('Invitation sent successfully');
      onSuccess?.();
      onClose();
    } catch (err: any) {
      const message = err instanceof Error ? err.message : 'Error sending invitation';
      toast.error(message);
      onError?.(err instanceof Error ? err : new Error(message));
    }
  };

  return (
    <div className="idp-dialog-overlay" onClick={onClose}>
      <div className="idp-dialog" onClick={(e: React.MouseEvent<HTMLDivElement>) => e.stopPropagation()}>
        <h3 className="idp-dialog-title">Invite Member</h3>
        
        <form onSubmit={handleSubmit}>
          <div className="idp-form-group">
            <label htmlFor="inviteEmail" className="idp-label">
              Email
            </label>
            <input
              id="inviteEmail"
              type="email"
              value={email}
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
              required
              disabled={loading}
              className="idp-input"
              placeholder="Enter email address"
            />
          </div>

          <div className="idp-form-group">
            <label htmlFor="inviteRole" className="idp-label">
              Role
            </label>
            <select
              id="inviteRole"
              value={role}
              onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setRole(e.target.value)}
              disabled={loading}
              className="idp-select"
            >
              <option value="member">Member</option>
              <option value="admin">Admin</option>
            </select>
          </div>

          {error && (
            <div className="idp-error-message" role="alert">
              {error.message}
            </div>
          )}

          <div className="idp-dialog-actions">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="idp-button idp-button-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="idp-button idp-button-primary"
            >
              {loading ? 'Sending...' : 'Send Invitation'}
            </button>
          </div>
        </form>
      </div>
      <ConfirmSaveDialog
        open={showConfirm}
        onOpenChange={setShowConfirm}
        title="Confirm send"
        description="Do you want to send the invitation to this email?"
        confirmLabel="Send invitation"
        cancelLabel="Cancel"
        onConfirm={handleConfirmInvite}
        loading={loading}
      />
    </div>
  );
};
