import { useState } from 'react';
import { OrganizationMembersList } from '@ait-saas-sso/idp-sdk';
import { useAuth } from '@ait-saas-sso/idp-sdk';

// Mock organization ID - en producción esto vendría del contexto o JWT
const MOCK_ORGANIZATION_ID = '00000000-0000-0000-0000-000000000001';

export const OrganizationPage = () => {
  const { user } = useAuth();
  const [selectedMember, setSelectedMember] = useState<string | null>(null);

  return (
    <div className="organization-page">
      <div className="page-header">
        <h1>Organization Management</h1>
        <p>Manage your organization members and roles</p>
      </div>

      <div className="organization-content">
        <div className="organization-info">
          <h2>Organization Details</h2>
          <div className="info-card">
            <p><strong>Organization ID:</strong> {MOCK_ORGANIZATION_ID}</p>
            <p><strong>Current User:</strong> {user?.email}</p>
          </div>
        </div>

        <div className="organization-members">
          <h2>Team Members</h2>
          <OrganizationMembersList
            organizationId={MOCK_ORGANIZATION_ID}
            onMemberClick={(memberId) => {
              setSelectedMember(memberId);
              console.log('Selected member:', memberId);
            }}
          />
        </div>

        {selectedMember && (
          <div className="member-details">
            <h3>Member Details</h3>
            <p>Member ID: {selectedMember}</p>
            <button onClick={() => setSelectedMember(null)}>Close</button>
          </div>
        )}
      </div>
    </div>
  );
};
