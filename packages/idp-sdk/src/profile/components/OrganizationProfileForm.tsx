/**
 * Organization Profile Form Component (modular)
 */

import React, { useState, FormEvent, useEffect } from 'react';
import { useOrganization } from '../hooks/useOrganization';

export interface OrganizationProfileFormProps {
  organizationId?: string;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
}

export const OrganizationProfileForm: React.FC<OrganizationProfileFormProps> = ({
  organizationId,
  onSuccess,
  onError,
  className = '',
}: OrganizationProfileFormProps) => {
  const { organization, loading, error, updateOrganization, updating } = useOrganization(organizationId);
  const [name, setName] = useState('');
  const [billingEmail, setBillingEmail] = useState('');

  useEffect(() => {
    if (organization) {
      setName(organization.name);
      setBillingEmail(organization.billing_email || '');
    }
  }, [organization]);

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    try {
      await updateOrganization({
        name,
        billing_email: billingEmail || null,
      });
      onSuccess?.();
    } catch (err: any) {
      onError?.(err);
    }
  };

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading organization...</div>;
  }

  if (!organization) {
    return <div className={`idp-error ${className}`}>Organization not found</div>;
  }

  return (
    <form onSubmit={handleSubmit} className={`idp-organization-profile-form ${className}`}>
      <h3 className="idp-form-title">Organization Information</h3>
      
      <div className="idp-form-group">
        <label htmlFor="orgName" className="idp-label">
          Organization Name
        </label>
        <input
          id="orgName"
          type="text"
          value={name}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setName(e.target.value)}
          required
          disabled={updating}
          className="idp-input"
          placeholder="Enter organization name"
        />
      </div>

      <div className="idp-form-group">
        <label htmlFor="billingEmail" className="idp-label">
          Billing Email
        </label>
        <input
          id="billingEmail"
          type="email"
          value={billingEmail}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setBillingEmail(e.target.value)}
          disabled={updating}
          className="idp-input"
          placeholder="Enter billing email"
        />
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
  );
};
