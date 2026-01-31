import { useState } from 'react';
import { UserProfileForm, OrganizationProfileForm } from '@ait-saas-sso/idp-sdk';
import { useAuth } from '@ait-saas-sso/idp-sdk';

export const ProfilePage = () => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<'user' | 'organization'>('user');

  return (
    <div className="profile-page">
      <div className="page-header">
        <h1>Profile Settings</h1>
      </div>

      <div className="profile-content">
        <div className="profile-tabs">
          <button
            className={activeTab === 'user' ? 'active' : ''}
            onClick={() => setActiveTab('user')}
          >
            User Profile
          </button>
          <button
            className={activeTab === 'organization' ? 'active' : ''}
            onClick={() => setActiveTab('organization')}
          >
            Organization Profile
          </button>
        </div>

        <div className="profile-form-container">
          {activeTab === 'user' ? (
            <div className="profile-section">
              <h2>User Information</h2>
              <UserProfileForm
                onSuccess={() => {
                  console.log('Profile updated successfully');
                  alert('Profile updated successfully!');
                }}
                onError={(error) => {
                  console.error('Error updating profile:', error);
                }}
              />
            </div>
          ) : (
            <div className="profile-section">
              <h2>Organization Information</h2>
              <OrganizationProfileForm
                onSuccess={() => {
                  console.log('Organization updated successfully');
                  alert('Organization updated successfully!');
                }}
                onError={(error) => {
                  console.error('Error updating organization:', error);
                }}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
