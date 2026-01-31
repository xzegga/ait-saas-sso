/**
 * Constants for the IDP SDK
 */

export const DEFAULT_PAGE_SIZE = 10;
export const MAX_PAGE_SIZE = 100;

export const USER_ROLES = {
  USER: 'user',
  SUPER_ADMIN: 'super_admin',
} as const;

export const SUBSCRIPTION_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  TRIAL: 'trial',
  CANCELLED: 'cancelled',
  PAST_DUE: 'past_due',
} as const;

export const PAYMENT_STATUS = {
  PENDING: 'pending',
  PAID: 'paid',
  FAILED: 'failed',
  REFUNDED: 'refunded',
} as const;

export const BILLING_INTERVALS = {
  MONTH: 'month',
  YEAR: 'year',
} as const;

export const MFA_POLICIES = {
  NONE: 'none',
  OPTIONAL: 'optional',
  REQUIRED: 'required',
} as const;
