/**
 * Organization Addresses Manager – add, edit, and delete addresses by type
 * (billing, shipping, legal, headquarters).
 */

import React, { useState, useCallback } from 'react';
import { useOrganizationAddresses } from '../hooks/useOrganizationAddresses';
import type {
  OrganizationAddress,
  OrganizationAddressType,
  OrganizationAddressCreate,
  OrganizationAddressUpdate,
} from '../../shared/types';

const ADDRESS_TYPES: { value: OrganizationAddressType; label: string }[] = [
  { value: 'billing', label: 'Billing' },
  { value: 'shipping', label: 'Shipping' },
  { value: 'legal', label: 'Legal' },
  { value: 'headquarters', label: 'Headquarters' },
];

function getAddressByType(addresses: OrganizationAddress[], type: OrganizationAddressType): OrganizationAddress | undefined {
  return addresses.find((a) => a.address_type === type);
}

const emptyForm = {
  line1: '',
  line2: '',
  city: '',
  state_region: '',
  postal_code: '',
  country_code: '',
};

export interface OrganizationAddressesManagerProps {
  organizationId: string;
  onSuccess?: () => void;
  onError?: (error: Error) => void;
  className?: string;
}

export const OrganizationAddressesManager: React.FC<OrganizationAddressesManagerProps> = ({
  organizationId,
  onSuccess,
  onError,
  className = '',
}) => {
  const { addresses, loading, error, addAddress, updateAddress, deleteAddress } = useOrganizationAddresses(organizationId);
  const [editingType, setEditingType] = useState<OrganizationAddressType | null>(null);
  const [addingType, setAddingType] = useState<OrganizationAddressType | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [deletingType, setDeletingType] = useState<OrganizationAddressType | null>(null);

  const resetForm = useCallback(() => {
    setForm(emptyForm);
    setEditingType(null);
    setAddingType(null);
  }, []);

  const fillForm = useCallback((addr: OrganizationAddress | null) => {
    if (!addr) {
      setForm(emptyForm);
      return;
    }
    setForm({
      line1: addr.line1 ?? '',
      line2: addr.line2 ?? '',
      city: addr.city ?? '',
      state_region: addr.state_region ?? '',
      postal_code: addr.postal_code ?? '',
      country_code: addr.country_code ?? '',
    });
  }, []);

  const handleStartAdd = (type: OrganizationAddressType) => {
    setAddingType(type);
    setForm(emptyForm);
    setEditingType(null);
  };

  const handleStartEdit = (addr: OrganizationAddress) => {
    setEditingType(addr.address_type);
    fillForm(addr);
    setAddingType(null);
  };

  const handleSaveAdd = async () => {
    if (!addingType) return;
    setSaving(true);
    try {
      await addAddress({
        address_type: addingType,
        ...form,
      });
      resetForm();
      onSuccess?.();
    } catch (err: any) {
      onError?.(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setSaving(false);
    }
  };

  const handleSaveEdit = async () => {
    if (!editingType) return;
    setSaving(true);
    try {
      await updateAddress(editingType, form);
      resetForm();
      onSuccess?.();
    } catch (err: any) {
      onError?.(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (type: OrganizationAddressType) => {
    if (!window.confirm(`Delete ${type} address?`)) return;
    setDeletingType(type);
    try {
      await deleteAddress(type);
      resetForm();
      onSuccess?.();
    } catch (err: any) {
      onError?.(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setDeletingType(null);
    }
  };

  const renderForm = (type: OrganizationAddressType, isAdd: boolean) => (
    <div className="idp-address-form">
      <div className="idp-form-group">
        <label className="idp-label">Street line 1</label>
        <input
          type="text"
          value={form.line1}
          onChange={(e) => setForm((f) => ({ ...f, line1: e.target.value }))}
          className="idp-input"
          placeholder="Street address"
        />
      </div>
      <div className="idp-form-group">
        <label className="idp-label">Street line 2</label>
        <input
          type="text"
          value={form.line2}
          onChange={(e) => setForm((f) => ({ ...f, line2: e.target.value }))}
          className="idp-input"
          placeholder="Apartment, suite, etc."
        />
      </div>
      <div className="idp-form-row">
        <div className="idp-form-group">
          <label className="idp-label">City</label>
          <input
            type="text"
            value={form.city}
            onChange={(e) => setForm((f) => ({ ...f, city: e.target.value }))}
            className="idp-input"
          />
        </div>
        <div className="idp-form-group">
          <label className="idp-label">State / Region</label>
          <input
            type="text"
            value={form.state_region}
            onChange={(e) => setForm((f) => ({ ...f, state_region: e.target.value }))}
            className="idp-input"
          />
        </div>
      </div>
      <div className="idp-form-row">
        <div className="idp-form-group">
          <label className="idp-label">Postal code</label>
          <input
            type="text"
            value={form.postal_code}
            onChange={(e) => setForm((f) => ({ ...f, postal_code: e.target.value }))}
            className="idp-input"
          />
        </div>
        <div className="idp-form-group">
          <label className="idp-label">Country (code)</label>
          <input
            type="text"
            value={form.country_code}
            onChange={(e) => setForm((f) => ({ ...f, country_code: e.target.value.toUpperCase().slice(0, 2) }))}
            className="idp-input"
            placeholder="e.g. ES, US"
            maxLength={2}
          />
        </div>
      </div>
      <div className="idp-form-actions">
        <button
          type="button"
          onClick={isAdd ? handleSaveAdd : handleSaveEdit}
          disabled={saving}
          className="idp-button idp-button-primary"
        >
          {saving ? 'Saving...' : 'Save'}
        </button>
        <button type="button" onClick={resetForm} className="idp-button idp-button-secondary">
          Cancel
        </button>
      </div>
    </div>
  );

  if (loading) {
    return <div className={`idp-loading ${className}`}>Loading addresses...</div>;
  }

  return (
    <div className={`idp-organization-addresses-manager ${className}`}>
      <h3 className="idp-form-title">Addresses</h3>
      {error && (
        <div className="idp-error-message" role="alert">
          {error.message}
        </div>
      )}

      {ADDRESS_TYPES.map(({ value: type, label }) => {
        const addr = getAddressByType(addresses, type);
        const isAdding = addingType === type;
        const isEditing = editingType === type;

        return (
          <div key={type} className="idp-address-block">
            <div className="idp-address-block-header">
              <h4 className="idp-address-type-title">{label} address</h4>
              {!addr && !isAdding && (
                <button
                  type="button"
                  onClick={() => handleStartAdd(type)}
                  className="idp-button idp-button-primary idp-button-sm"
                >
                  Add {label} address
                </button>
              )}
              {addr && !isEditing && (
                <>
                  <button
                    type="button"
                    onClick={() => handleStartEdit(addr)}
                    className="idp-button idp-button-secondary idp-button-sm"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(type)}
                    disabled={deletingType === type}
                    className="idp-button idp-button-danger idp-button-sm"
                  >
                    {deletingType === type ? 'Deleting...' : 'Delete'}
                  </button>
                </>
              )}
            </div>

            {addr && !isEditing && (
              <div className="idp-address-display">
                {[addr.line1, addr.line2, [addr.city, addr.state_region].filter(Boolean).join(', '), addr.postal_code, addr.country_code]
                  .filter(Boolean)
                  .map((line, i) => (
                    <p key={i} className="idp-address-line">
                      {line}
                    </p>
                  ))}
                {![addr.line1, addr.line2, addr.city, addr.postal_code, addr.country_code].some(Boolean) && (
                  <p className="idp-address-line idp-text-muted">No address details</p>
                )}
              </div>
            )}

            {(isAdding || isEditing) && renderForm(type, isAdding)}
          </div>
        );
      })}
    </div>
  );
};
