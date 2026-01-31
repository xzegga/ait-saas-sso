/**
 * Sign Up Form Component
 * Handles complete user registration with organization creation and plan selection
 * Two-step flow: 1) User info, 2) Plan selection with cards
 */

import React, { useState, FormEvent, useEffect, useMemo } from 'react';
import { useSignUp } from '../hooks/useSignUp';
import { useIDP } from '../../providers/IDPProvider';
import { useBillingIntervals } from '../../billing/hooks/useBillingIntervals';
import { logger } from '../../shared/logger';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Alert, AlertDescription, AlertTitle } from '../../components/ui/alert';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '../../components/ui/card';
import { ToggleGroup, ToggleGroupItem } from '../../components/ui/toggle-group';
import { AlertCircle, Check, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { AvailablePlan } from '../../billing/hooks/useAvailablePlans';

// Icon component to avoid React type conflicts between React 18 and 19
const Icon: React.FC<{ icon: typeof AlertCircle | typeof Check | typeof X; className?: string }> = ({ 
  icon: IconComponent, 
  className 
}) => {
  const Component = IconComponent as any;
  return <Component className={className} />;
};

export interface SignUpFormProps {
  onSuccess?: (data: { orgId: string; subscriptionId: string; status: 'trial' | 'active' }) => void;
  onError?: (error: Error) => void;
  onStepChange?: (step: 1 | 2) => void;
  className?: string;
  availablePlans?: AvailablePlan[];
}

interface FormData {
  email: string;
  password: string;
  fullName: string;
  orgName: string;
  useUserName: boolean;
}

export const SignUpForm: React.FC<SignUpFormProps> = ({
  onSuccess,
  onError,
  onStepChange,
  className = '',
  availablePlans = [],
}: SignUpFormProps) => {
  const { signUp, loading, error } = useSignUp();
  const { validationError, isValidating, config } = useIDP();
  const { intervals: billingIntervals } = useBillingIntervals();
  
  // Step management
  const [step, setStep] = useState<1 | 2>(1);
  
  // Form state
  const [formData, setFormData] = useState<FormData>({
    email: '',
    password: '',
    fullName: '',
    orgName: '',
    useUserName: true,
  });
  const [showOrgField, setShowOrgField] = useState(false);
  const [selectedBillingInterval, setSelectedBillingInterval] = useState<string>('month');

  const hasValidationError = !!(validationError && config.clientSecret);
  const isDisabled = hasValidationError || isValidating || loading;

  // Get default billing interval (first one or 'month')
  useEffect(() => {
    if (billingIntervals.length > 0 && !selectedBillingInterval) {
      const defaultInterval = billingIntervals.find(bi => bi.key === 'month') || billingIntervals[0];
      if (defaultInterval) {
        setSelectedBillingInterval(defaultInterval.key);
      }
    }
  }, [billingIntervals, selectedBillingInterval]);

  // Update org name when checkbox changes
  useEffect(() => {
    if (formData.useUserName) {
      setFormData(prev => ({ ...prev, orgName: prev.fullName || '' }));
      setShowOrgField(false);
    } else {
      setShowOrgField(true);
      if (formData.orgName === formData.fullName) {
        setFormData(prev => ({ ...prev, orgName: '' }));
      }
    }
  }, [formData.useUserName, formData.fullName]);

  const handleStep1Submit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    if (hasValidationError) {
      return;
    }

    // Validate required fields
    if (!formData.fullName || !formData.email || !formData.password) {
      const err = new Error('Please fill in all required fields');
      logger.error('Signup validation error', err);
      onError?.(err);
      return;
    }

    // Move to step 2
    setStep(2);
    onStepChange?.(2);
  };

  const handlePlanSignUp = async (planId: string, productPlanId: string) => {
    if (hasValidationError) {
      return;
    }

    if (!config.productId) {
      const err = new Error('Product ID is not configured');
      logger.error('Signup configuration error', err);
      onError?.(err);
      return;
    }

    try {
      const result = await signUp({
        email: formData.email,
        password: formData.password,
        fullName: formData.fullName,
        productId: config.productId,
        planId,
        billingInterval: selectedBillingInterval,
        orgName: formData.useUserName ? undefined : formData.orgName,
        useUserName: formData.useUserName,
      });

      logger.info('Sign up completed successfully', result);
      onSuccess?.({
        orgId: result.orgId,
        subscriptionId: result.subscriptionId,
        status: result.status,
      });
    } catch (err: any) {
      logger.error('Sign up error', err);
      onError?.(err);
    }
  };

  // Step 1: User Information Form
  if (step === 1) {
    return (
      <form onSubmit={handleStep1Submit} className={cn('idp-space-y-4', className)}>
        {/* Client Secret Validation Error */}
        {hasValidationError && (
          <Alert variant="warning" className="idp-mb-6">
            <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
            <AlertTitle>Configuration Error</AlertTitle>
            <AlertDescription>
              <p className="idp-mb-2">{validationError.message}</p>
              <p className="idp-text-xs idp-opacity-80">
                Please check your VITE_CLIENT_SECRET and VITE_PRODUCT_ID environment variables.
              </p>
            </AlertDescription>
          </Alert>
        )}

        {/* User Information */}
        <div className="idp-space-y-2">
          <Label htmlFor="fullName">Full Name</Label>
          <Input
            id="fullName"
            type="text"
            value={formData.fullName}
            onChange={(e) => setFormData(prev => ({ ...prev, fullName: e.target.value }))}
            required
            disabled={isDisabled}
            placeholder="Enter your full name"
          />
        </div>

        <div className="idp-space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            value={formData.email}
            onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
            required
            disabled={isDisabled}
            placeholder="Enter your email"
          />
        </div>

        <div className="idp-space-y-2">
          <Label htmlFor="password">Password</Label>
          <Input
            id="password"
            type="password"
            value={formData.password}
            onChange={(e) => setFormData(prev => ({ ...prev, password: e.target.value }))}
            required
            disabled={isDisabled}
            placeholder="Enter your password"
            minLength={6}
          />
          <p className="idp-text-xs idp-text-muted-foreground">
            Password must be at least 6 characters
          </p>
        </div>

        {/* Organization Name */}
        <div className="idp-space-y-2">
          <div className="idp-flex idp-items-center idp-space-x-2">
            <input
              type="checkbox"
              id="useUserName"
              checked={formData.useUserName}
              onChange={(e) => setFormData(prev => ({ ...prev, useUserName: e.target.checked }))}
              disabled={isDisabled}
              className="idp-h-4 idp-w-4 idp-rounded idp-border-input idp-cursor-pointer disabled:idp-cursor-not-allowed"
            />
            <Label htmlFor="useUserName" className="idp-font-normal idp-cursor-pointer">
              Use my name as organization name
            </Label>
          </div>
          
          {showOrgField && (
            <div className="idp-mt-2">
              <Label htmlFor="orgName">Organization Name</Label>
              <Input
                id="orgName"
                type="text"
                value={formData.orgName}
                onChange={(e) => setFormData(prev => ({ ...prev, orgName: e.target.value }))}
                required={!formData.useUserName}
                disabled={isDisabled || formData.useUserName}
                placeholder="Enter organization name"
              />
            </div>
          )}
        </div>

        {/* Error Message */}
        {error && !hasValidationError && (
          <Alert variant="destructive">
            <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
            <AlertDescription>{error.message}</AlertDescription>
          </Alert>
        )}

        <Button
          type="submit"
          disabled={isDisabled}
          className="idp-w-full"
        >
          {isValidating ? 'Validating...' : 'Continue'}
        </Button>
      </form>
    );
  }

  // Step 2: Plan Selection with Cards
  // Get price for selected billing interval for each plan
  const getPlanPrice = (plan: AvailablePlan, intervalKey: string) => {
    const price = plan.prices?.find(p => p.billing_interval === intervalKey);
    return price || plan.prices?.find(p => p.is_default) || plan.prices?.[0];
  };

  // Calculate discount percentage compared to monthly price
  const calculateDiscount = (plan: AvailablePlan, intervalKey: string): number | null => {
    if (intervalKey === 'month') return null; // No discount for monthly
    
    const monthlyPrice = plan.prices?.find(p => p.billing_interval === 'month');
    const selectedPrice = getPlanPrice(plan, intervalKey);
    
    if (!monthlyPrice || !selectedPrice || monthlyPrice.price === 0) return null;
    
    // Calculate equivalent monthly price for selected interval
    const monthlyInterval = billingIntervals.find(bi => bi.key === 'month');
    const selectedInterval = billingIntervals.find(bi => bi.key === intervalKey);
    
    if (!monthlyInterval || !selectedInterval || !monthlyInterval.days || !selectedInterval.days) return null;
    
    // Calculate equivalent monthly price: (selectedPrice / selectedInterval.days) * monthlyInterval.days
    const equivalentMonthlyPrice = (selectedPrice.price / selectedInterval.days) * monthlyInterval.days;
    
    // Calculate discount: ((monthlyPrice - equivalentMonthlyPrice) / monthlyPrice) * 100
    const discount = ((monthlyPrice.price - equivalentMonthlyPrice) / monthlyPrice.price) * 100;
    
    return discount > 0 ? Math.round(discount) : null;
  };

  return (
    <div className={cn('idp-space-y-6', className)}>
      {/* Back button */}
      <Button
        type="button"
        variant="ghost"
        onClick={() => {
          setStep(1);
          onStepChange?.(1);
        }}
        disabled={loading}
        className="idp-mb-4"
      >
        ← Back
      </Button>

      {/* Header */}
      <div className="idp-text-center idp-space-y-6">
        <div>
          <h2 className="idp-text-2xl idp-font-bold">Choose Your Plan</h2>
          <p className="idp-text-muted-foreground idp-mt-2">
            Select the plan that best fits your needs
          </p>
        </div>

        {/* Billing Interval Selector - Simple Toggle Style */}
        {billingIntervals.length > 0 && (
          <div className="idp-flex idp-justify-center">
            <ToggleGroup
              type="single"
              value={selectedBillingInterval}
              onValueChange={(value: string | undefined) => {
                if (value) setSelectedBillingInterval(value);
              }}
              className="idp-inline-flex idp-bg-gray-100 dark:idp-bg-gray-800 idp-rounded-lg idp-p-1 idp-gap-0"
            >
              {billingIntervals.map((interval) => (
                <ToggleGroupItem
                  key={interval.key}
                  value={interval.key}
                  aria-label={interval.label}
                  className={cn(
                    'idp-px-6 idp-py-2 idp-text-sm idp-font-medium idp-rounded-md idp-transition-all idp-border-0',
                    selectedBillingInterval === interval.key
                      ? 'idp-bg-blue-600 idp-text-white idp-shadow-sm'
                      : 'idp-bg-transparent idp-text-gray-600 dark:idp-text-gray-400 hover:idp-text-gray-900 dark:hover:idp-text-gray-100'
                  )}
                >
                  {interval.label}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>
        )}
      </div>

      {/* Plans Grid - Centered */}
      {availablePlans.length > 0 ? (
        <div className="idp-flex idp-justify-center idp-items-center">
          <div className="idp-grid idp-gap-6 idp-grid-cols-1 md:idp-grid-cols-2 lg:idp-grid-cols-3 idp-w-full idp-max-w-5xl">
            {availablePlans.map((plan, index) => {
              const isTrialEligible = plan.is_trial_eligible;
              const selectedPrice = getPlanPrice(plan, selectedBillingInterval);
              const discount = calculateDiscount(plan, selectedBillingInterval);
              const priceDisplay = selectedPrice 
                ? `$${selectedPrice.price.toFixed(0)}` 
                : 'Free';
              const currency = selectedPrice?.currency || 'USD';
              const billingPeriodLabel = billingIntervals.find(bi => bi.key === selectedBillingInterval)?.label || 'Month';

              // Simple color scheme based on plan index
              const colorSchemes = [
                { 
                  button: 'idp-bg-blue-600 hover:idp-bg-blue-700',
                  text: 'idp-text-blue-600',
                },
                { 
                  button: 'idp-bg-purple-600 hover:idp-bg-purple-700',
                  text: 'idp-text-purple-600',
                },
                { 
                  button: 'idp-bg-pink-600 hover:idp-bg-pink-700',
                  text: 'idp-text-pink-600',
                },
              ];
              const colorScheme = colorSchemes[index % colorSchemes.length];

              return (
                <Card 
                  key={plan.id} 
                  className={cn(
                    'idp-relative idp-overflow-hidden idp-transition-all hover:idp-shadow-lg idp-border idp-h-full idp-flex idp-flex-col',
                    loading && 'idp-opacity-50 idp-pointer-events-none'
                  )}
                >
                  <CardHeader className="idp-pb-4">
                    <div className="idp-flex idp-items-baseline idp-justify-between idp-mb-2">
                      <CardTitle className={cn('idp-text-3xl idp-font-bold', colorScheme.text)}>
                        {plan.name.toUpperCase()}
                      </CardTitle>
                      {selectedPrice && selectedPrice.price > 0 && (
                        <div className="idp-text-right">
                          <div className={cn('idp-text-2xl idp-font-bold', colorScheme.text)}>
                            {priceDisplay}
                          </div>
                          {discount && discount > 0 && (
                            <div className="idp-text-xs idp-text-green-600 dark:idp-text-green-400 idp-font-medium idp-mt-1">
                              Save {discount}%
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                    <CardDescription className="idp-text-sm idp-text-muted-foreground">
                      PER {billingPeriodLabel.toUpperCase()}
                    </CardDescription>
                  </CardHeader>

                  <CardContent className="idp-space-y-4 idp-flex-1 idp-flex idp-flex-col idp-pt-0">
                    {/* Features List from Entitlements */}
                    <div className="idp-space-y-3 idp-flex-1">
                      {plan.entitlements && plan.entitlements.length > 0 ? (
                        plan.entitlements.map((entitlement, idx) => {
                          // Parse value based on data_type
                          let displayValue = entitlement.value_text || '';
                          let isIncluded = true;
                          
                          if (entitlement.data_type === 'boolean') {
                            isIncluded = displayValue === 'true' || displayValue === '1';
                            displayValue = entitlement.description || entitlement.key;
                          } else if (entitlement.data_type === 'number') {
                            displayValue = `${entitlement.description || entitlement.key}: ${displayValue}`;
                          } else {
                            displayValue = `${entitlement.description || entitlement.key}${displayValue ? `: ${displayValue}` : ''}`;
                          }

                          return (
                            <div key={idx} className="idp-flex idp-items-center idp-space-x-2">
                              {isIncluded ? (
                                <Icon icon={Check} className="idp-h-4 idp-w-4 idp-text-green-500 idp-flex-shrink-0" />
                              ) : (
                                <Icon icon={X} className="idp-h-4 idp-w-4 idp-text-red-500 idp-flex-shrink-0" />
                              )}
                              <span className="idp-text-sm idp-text-foreground">{displayValue}</span>
                            </div>
                          );
                        })
                      ) : (
                        // Fallback if no entitlements
                        <div className="idp-text-sm idp-text-muted-foreground idp-italic">
                          No features specified
                        </div>
                      )}
                    </div>

                    {/* Trial Info */}
                    {isTrialEligible && (
                      <div className="idp-mt-auto idp-p-3 idp-bg-blue-50 dark:idp-bg-blue-950 idp-rounded-md idp-border idp-border-blue-200 dark:idp-border-blue-800">
                        <div className="idp-flex idp-items-center idp-space-x-2">
                          <Icon icon={Check} className="idp-h-4 idp-w-4 idp-text-green-500" />
                          <p className="idp-text-xs idp-text-blue-700 dark:idp-text-blue-300">
                            Free trial available. Your subscription will activate after the trial period.
                          </p>
                        </div>
                      </div>
                    )}
                  </CardContent>

                  <CardFooter className="idp-p-6 idp-pt-4">
                    <Button
                      onClick={() => handlePlanSignUp(plan.id, plan.product_plan_id)}
                      disabled={loading || isDisabled}
                      className={cn('idp-w-full idp-text-white idp-font-semibold', colorScheme.button)}
                      size="lg"
                    >
                      {loading ? 'Creating account...' : 'Choose'}
                    </Button>
                  </CardFooter>
                </Card>
              );
            })}
          </div>
        </div>
      ) : (
        <Alert variant="warning">
          <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
          <AlertDescription>
            No plans available. Please contact support or try again later.
          </AlertDescription>
        </Alert>
      )}

      {/* Error Message */}
      {error && !hasValidationError && (
        <Alert variant="destructive">
          <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
          <AlertDescription>{error.message}</AlertDescription>
        </Alert>
      )}
    </div>
  );
};
