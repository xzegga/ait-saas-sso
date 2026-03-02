/**
 * Organization Profile Form Component (modular)
 * Supports base fields plus extended: slug, legal_name, tax_id, support_email, phone.
 */

import React, { useState, FormEvent, useEffect } from 'react';
import { toast } from 'sonner';
import { useOrganization } from '../hooks/useOrganization';
import { ConfirmSaveDialog } from '../../shared/components/ConfirmSaveDialog';

export interface OrganizationProfileFormProps {
  organizationId?: string;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
  /** If true, show extended fields (slug, legal_name, tax_id, support_email, phone). Default true. */
  showExtendedFields?: boolean;
}

export const OrganizationProfileForm: React.FC<OrganizationProfileFormProps> = ({
  organizationId,
  onSuccess,
  onError,
  className = '',
  showExtendedFields = true,
}: OrganizationProfileFormProps) => {
  const { organization, loading, error, updateOrganization, updating } = useOrganization(organizationId);
  const [name, setName] = useState('');
  const [billingEmail, setBillingEmail] = useState('');
  const [slug, setSlug] = useState('');
  const [legalName, setLegalName] = useState('');
  const [taxId, setTaxId] = useState('');
  const [supportEmail, setSupportEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [showConfirm, setShowConfirm] = useState(false);

  useEffect(() => {
    if (organization) {
      setName(organization.name);
      setBillingEmail(organization.billing_email || '');
      setSlug(organization.slug ?? '');
      setLegalName(organization.legal_name ?? '');
      setTaxId(organization.tax_id ?? '');
      setSupportEmail(organization.support_email ?? '');
      setPhone(organization.phone ?? '');
    }
  }, [organization]);

  const handleSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setShowConfirm(true);
  };

  const handleConfirmSave = async () => {
    try {
      await updateOrganization({
        name,
        billing_email: billingEmail || null,
        ...(showExtendedFields && {
          slug: slug || null,
          legal_name: legalName || null,
          tax_id: taxId || null,
          support_email: supportEmail || null,
          phone: phone || null,
        }),
      });
      toast.success('Organization updated successfully');
      onSuccess?.();
    } catch (err: any) {
      const message = err instanceof Error ? err.message : 'Error saving changes';
      toast.error(message);
      onError?.(err instanceof Error ? err : new Error(message));
    }
  };

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading organization...</div>;
  }

  if (!organization) {
    return <div className={`idp-error ${className}`}>Organization not found</div>;
  }

  return (
    <div className={`idp-card idp-organization-profile-form ${className}`}>
      <div className="idp-card-header">
        <h3 className="idp-card-title">Organization Information</h3>
      </div>
      <form onSubmit={handleSubmit} className="idp-card-body">
        <div className="idp-form-section">
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
        </div>

        {showExtendedFields && (
          <div className={`idp-form-section idp-form-grid idp-form-grid-2`}>
            <div className="idp-form-group">
              <label htmlFor="orgSlug" className="idp-label">
                Slug (URL identifier)
              </label>
              <input
                id="orgSlug"
                type="text"
                value={slug}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setSlug(e.target.value)}
                disabled={updating}
                className="idp-input"
                placeholder="e.g. acme-corp"
              />
            </div>
            <div className="idp-form-group">
              <label htmlFor="legalName" className="idp-label">
                Legal Name
              </label>
              <input
                id="legalName"
                type="text"
                value={legalName}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setLegalName(e.target.value)}
                disabled={updating}
                className="idp-input"
                placeholder="Registered company name"
              />
            </div>
            <div className="idp-form-group">
              <label htmlFor="taxId" className="idp-label">
                Tax ID / VAT
              </label>
              <input
                id="taxId"
                type="text"
                value={taxId}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setTaxId(e.target.value)}
                disabled={updating}
                className="idp-input"
                placeholder="NIF, VAT, EIN, etc."
              />
            </div>
            <div className="idp-form-group">
              <label htmlFor="supportEmail" className="idp-label">
                Support Email
              </label>
              <input
                id="supportEmail"
                type="email"
                value={supportEmail}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setSupportEmail(e.target.value)}
                disabled={updating}
                className="idp-input"
                placeholder="Support or contact email"
              />
            </div>
            <div className="idp-form-group idp-form-group-full">
              <label htmlFor="orgPhone" className="idp-label">
                Phone
              </label>
              <input
                id="orgPhone"
                type="tel"
                value={phone}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPhone(e.target.value)}
                disabled={updating}
                className="idp-input"
                placeholder="Primary contact phone"
              />
            </div>
          </div>
        )}

        {error && (
          <div className="idp-error-message" role="alert">
            {error.message}
          </div>
        )}

        <div className="idp-form-actions">
          <button
            type="submit"
            disabled={updating}
            className="idp-button idp-button-primary"
          >
            {updating ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </form>
      <ConfirmSaveDialog
        open={showConfirm}
        onOpenChange={setShowConfirm}
        title="Confirm save"
        description="Do you want to save the organization changes?"
        confirmLabel="Save"
        cancelLabel="Cancel"
        onConfirm={handleConfirmSave}
        loading={updating}
      />
    </div>
  );
};
