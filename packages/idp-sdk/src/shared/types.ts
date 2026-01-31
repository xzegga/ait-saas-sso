/**
 * Shared TypeScript types for the IDP SDK
 */

export interface User {
  id: string;
  email: string | null;
  full_name: string | null;
  avatar_url: string | null;
  role: string; // 'user' | 'super_admin'
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface UserUpdate {
  full_name?: string | null;
  avatar_url?: string | null;
  role?: string;
}

export interface Organization {
  id: string;
  name: string;
  billing_email: string | null;
  mfa_policy: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface OrganizationCreate {
  name: string;
  billing_email?: string | null;
  mfa_policy?: string;
}

export interface OrganizationUpdate {
  name?: string;
  billing_email?: string | null;
  mfa_policy?: string;
  deleted_at?: string | null;
}

export interface OrganizationMember {
  id: string;
  org_id: string;
  user_id: string;
  role: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  user?: User;
  organization?: Organization;
}

export interface Product {
  id: string;
  name: string;
  description: string | null;
  client_id: string | null;
  client_secret: string | null;
  redirect_urls: string[] | null;
  status: boolean;
  created_at: string;
  deleted_at: string | null;
}

export interface Plan {
  id: string;
  name: string;
  description: string | null;
  features: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface ProductPlan {
  id: string;
  product_id: string;
  plan_id: string;
  price: number | null;
  currency: string;
  is_public: boolean;
  status: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  plan?: Plan;
  prices_by_interval?: ProductPlanPrice[];
}

export interface ProductPlanPrice {
  id: string;
  product_plan_id: string;
  billing_interval: string;
  price: number;
  currency: string;
  discount_percentage: number | null;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

export interface BillingInterval {
  id: string;
  key: string;
  label: string;
  description: string | null;
  days: number;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface Subscription {
  id: string;
  org_id: string;
  product_id: string;
  product_plan_id: string;
  status: string;
  current_period_start: string | null;
  current_period_end: string | null;
  trial_starts_at: string | null;
  trial_ends_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  organization?: Organization;
  product?: Product;
  product_plan?: ProductPlan;
}

export interface PaymentAccount {
  id: string;
  org_id: string;
  provider_id: string;
  external_account_id: string;
  provider_name?: string;
  organization?: Organization;
}

export interface PaymentSubscription {
  id: string;
  subscription_id: string;
  payment_account_id: string;
  provider_id: string;
  external_subscription_id: string;
  status: string;
  current_period_start: string | null;
  current_period_end: string | null;
  provider_name?: string;
}

export interface PaymentInvoice {
  id: string;
  org_id: string;
  provider_id: string;
  external_invoice_id: string;
  amount: number;
  currency: string;
  status: string;
  invoice_url: string | null;
  pdf_url: string | null;
  created_at: string;
  provider_name?: string;
  organization?: Organization;
}

export interface JWTPayload {
  sub: string;
  email?: string;
  role?: string;
  org_id?: string;
  permissions?: string[];
  [key: string]: unknown;
}

export interface IDPConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
  productId?: string;
  organizationId?: string;
  clientSecret?: string;
}
