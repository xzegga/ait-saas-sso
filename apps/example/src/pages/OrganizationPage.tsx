import { useState } from 'react';
import {
  OrganizationMembersList,
  OrganizationProfileForm,
  OrganizationAddressesManager,
  useAuth,
  useOrganization,
} from '@ait-saas-sso/idp-sdk';

// Fallback for development when org is not in JWT yet
const MOCK_ORGANIZATION_ID = '00000000-0000-0000-0000-000000000001';

export const OrganizationPage = () => {
  const { user } = useAuth();
  const { organization } = useOrganization();
  const [selectedMember, setSelectedMember] = useState<string | null>(null);

  const organizationId = organization?.id ?? MOCK_ORGANIZATION_ID;

  return (
    <div className="organization-page">
      <div className="page-header">
        <h1>Organization Management</h1>
        <p>Manage your organization members and roles</p>
      </div>

      <div className="organization-content">
        <div className="organization-info">
          <h2 className="idp-section-title">Organization Details</h2>
          <div className="idp-user-banner">
            <strong>Current User:</strong> {user?.email ?? '—'}
          </div>
          <div className="flex gap-4 w-full [&>div]:flex-1">
            <OrganizationProfileForm
              organizationId={organization?.id}
              showExtendedFields
            />
            <OrganizationAddressesManager organizationId={organizationId} />
        </div>
        </div>

       

        <div className="organization-members" style={{ marginTop: '1.5rem' }}>
          <h2 className="idp-section-title">Team Members</h2>
          <OrganizationMembersList
            organizationId={organizationId}
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
