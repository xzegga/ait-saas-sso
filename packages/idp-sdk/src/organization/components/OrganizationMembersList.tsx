/**
 * Organization Members List Component (modular)
 */

import React, { useState } from 'react';
import { useOrganizationMembers } from '../hooks/useOrganizationMembers';
import { InviteMemberDialog } from './InviteMemberDialog';

export interface OrganizationMembersListProps {
  organizationId: string;
  onMemberClick?: (memberId: string) => void;
  className?: string;
}

export const OrganizationMembersList: React.FC<OrganizationMembersListProps> = ({
  organizationId,
  onMemberClick,
  className = '',
}: OrganizationMembersListProps) => {
  const { members, loading, error } = useOrganizationMembers(organizationId);
  const [showInviteDialog, setShowInviteDialog] = useState(false);

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading members...</div>;
  }

  if (error) {
    return <div className={`idp-error ${className}`}>{error.message}</div>;
  }

  return (
    <div className={`idp-organization-members-list ${className}`}>
      <div className="idp-list-header">
        <h3 className="idp-list-title">Members</h3>
        <button
          onClick={() => setShowInviteDialog(true)}
          className="idp-button idp-button-primary"
        >
          Invite Member
        </button>
      </div>

      {members.length === 0 ? (
        <p className="idp-empty-state">No members found</p>
      ) : (
        <ul className="idp-members-list">
          {members.map((member) => (
            <li
              key={member.id}
              className="idp-member-item"
              onClick={() => onMemberClick?.(member.id)}
            >
              <div className="idp-member-info">
                <span className="idp-member-name">
                  {member.user?.full_name || member.user?.email || 'Unknown'}
                </span>
                <span className="idp-member-role">{member.role}</span>
              </div>
            </li>
          ))}
        </ul>
      )}

      {showInviteDialog && (
        <InviteMemberDialog
          organizationId={organizationId}
          onClose={() => setShowInviteDialog(false)}
          onSuccess={() => setShowInviteDialog(false)}
        />
      )}
    </div>
  );
};
