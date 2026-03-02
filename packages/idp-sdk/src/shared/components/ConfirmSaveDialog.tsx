/**
 * Confirm save dialog – asks user to confirm before submitting/saving.
 * Uses Radix AlertDialog. Consuming app must render sonner's <Toaster /> for toasts.
 */

import React from 'react';
import * as AlertDialog from '@radix-ui/react-alert-dialog';

export interface ConfirmSaveDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title?: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm: () => void | Promise<void>;
  loading?: boolean;
}

const defaultTitle = 'Confirm save';
const defaultDescription = 'Do you want to save your changes?';
const defaultConfirmLabel = 'Save';
const defaultCancelLabel = 'Cancel';

export const ConfirmSaveDialog: React.FC<ConfirmSaveDialogProps> = ({
  open,
  onOpenChange,
  title = defaultTitle,
  description = defaultDescription,
  confirmLabel = defaultConfirmLabel,
  cancelLabel = defaultCancelLabel,
  onConfirm,
  loading = false,
}) => {
  const handleConfirm = async () => {
    await onConfirm();
    onOpenChange(false);
  };

  return (
    <AlertDialog.Root open={open} onOpenChange={onOpenChange}>
      <AlertDialog.Portal>
        <AlertDialog.Overlay className="idp-dialog-overlay" style={{ position: 'fixed', inset: 0, zIndex: 9998, backgroundColor: 'rgba(0,0,0,0.5)' }} />
        <AlertDialog.Content
          className="idp-card idp-dialog"
          style={{
            position: 'fixed',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            zIndex: 9999,
            maxWidth: '24rem',
            padding: '1.5rem',
          }}
          onEscapeKeyDown={() => !loading && onOpenChange(false)}
        >
          <AlertDialog.Title className="idp-card-title" style={{ marginBottom: '0.5rem' }}>
            {title}
          </AlertDialog.Title>
          <AlertDialog.Description className="idp-text-muted" style={{ marginBottom: '1.25rem', fontSize: '0.875rem' }}>
            {description}
          </AlertDialog.Description>
          <div className="idp-form-actions" style={{ borderTop: 'none', paddingTop: 0, marginTop: 0 }}>
            <AlertDialog.Cancel asChild>
              <button type="button" className="idp-button idp-button-secondary" disabled={loading}>
                {cancelLabel}
              </button>
            </AlertDialog.Cancel>
            <button
              type="button"
              className="idp-button idp-button-primary"
              disabled={loading}
              onClick={() => handleConfirm()}
            >
              {loading ? 'Saving...' : confirmLabel}
            </button>
          </div>
        </AlertDialog.Content>
      </AlertDialog.Portal>
    </AlertDialog.Root>
  );
};
