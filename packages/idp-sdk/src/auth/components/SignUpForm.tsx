/**
 * Sign Up Form Component
 * New flow: 1) User info → Create user → 2) Verification → 3) Plan selection
 */

import React, { useState, FormEvent, useEffect, useMemo } from 'react';
import { toast } from 'sonner';
import { useSignUp } from '../hooks/useSignUp';
import { useVerifyOtp } from '../hooks/useVerifyOtp';
import { useCompleteSignup } from '../hooks/useCompleteSignup';
import { useIDP } from '../../providers/IDPProvider';
import { useBillingIntervals } from '../../billing/hooks/useBillingIntervals';
import { logger } from '../../shared/logger';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Alert, AlertDescription, AlertTitle } from '../../components/ui/alert';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '../../components/ui/card';
import { ToggleGroup, ToggleGroupItem } from '../../components/ui/toggle-group';
import { VerificationRequired } from './VerificationRequired';
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
  onStepChange?: (step: 1 | 2 | 3) => void;
  className?: string;
  availablePlans?: AvailablePlan[];
}

interface FormData {
  email: string;
  password: string;
  confirmPassword: string;
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
}) => {
  const { signUp, loading: signUpLoading, error: signUpError } = useSignUp();
  const { verifyOtp, loading: verifyingOtp, error: verifyError } = useVerifyOtp();
  const { completeSignup, loading: completeLoading, error: completeError } = useCompleteSignup();
  const { validationError, isValidating, config, supabase } = useIDP();
  const { intervals: allBillingIntervals } = useBillingIntervals();
  
  // Step management (1: User info, 2: Verification, 3: Plan selection)
  const [step, setStep] = useState<1 | 2 | 3>(1);
  
  // Form state
  const [formData, setFormData] = useState<FormData>({
    email: '',
    password: '',
    confirmPassword: '',
    fullName: '',
    orgName: '',
    useUserName: true,
  });
  
  // Store signup result for verification step
  const [signupResult, setSignupResult] = useState<{ userId: string; email: string } | null>(null);
  const [showOrgField, setShowOrgField] = useState(false);
  const [selectedBillingInterval, setSelectedBillingInterval] = useState<string>('month');
  
  // Filter billing intervals to only show those with prices configured for available plans
  const billingIntervals = useMemo(() => {
    if (availablePlans.length === 0) {
      logger.debug('No available plans, returning all billing intervals', { count: allBillingIntervals.length });
      return allBillingIntervals;
    }
    
    // Get all unique billing intervals that have prices configured in any plan
    const configuredIntervals = new Set<string>();
    availablePlans.forEach(plan => {
      plan.prices?.forEach(price => {
        if (price.billing_interval) {
          configuredIntervals.add(price.billing_interval);
        }
      });
    });
    
    // Filter billing intervals to only include configured ones
    const filtered = allBillingIntervals.filter(bi => configuredIntervals.has(bi.key));
    
    return filtered;
  }, [allBillingIntervals, availablePlans]);
  
  // Update selected billing interval if it's not in the filtered list
  useEffect(() => {
    if (billingIntervals.length > 0) {
      const intervalExists = billingIntervals.some(bi => bi.key === selectedBillingInterval);
      if (!intervalExists) {
        const defaultInterval = billingIntervals.find(bi => bi.key === 'month') || billingIntervals[0];
        if (defaultInterval) {
          setSelectedBillingInterval(defaultInterval.key);
        }
      }
    }
  }, [billingIntervals, selectedBillingInterval]);

  const hasValidationError = !!(validationError && config.clientSecret);
  const isDisabled = hasValidationError || isValidating || signUpLoading || verifyingOtp || completeLoading;
  const currentError = signUpError || verifyError || completeError;

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

  // Step 1: User Information Form → Create user → Step 2 (Verification)
  const handleStep1Submit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    
    if (hasValidationError) {
      return;
    }

    // Validate required fields
    if (!formData.fullName || !formData.email || !formData.password || !formData.confirmPassword) {
      const err = new Error('Please fill in all required fields');
      logger.error('Signup validation error', err);
      toast.error('Please fill in all required fields');
      onError?.(err);
      return;
    }

    // Validate password match
    if (formData.password !== formData.confirmPassword) {
      const err = new Error('Passwords do not match');
      logger.error('Signup validation error', err);
      toast.error('Passwords do not match');
      onError?.(err);
      return;
    }

    try {
      // Create user (without org/subscription)
      const result = await signUp({
        email: formData.email,
        password: formData.password,
        confirmPassword: formData.confirmPassword,
        fullName: formData.fullName,
        orgName: formData.useUserName ? undefined : formData.orgName,
        useUserName: formData.useUserName,
      });

      logger.info('User created, moving to verification', result);
      toast.success('Account created. Check your email to verify.');
      // Store result and move to verification step
      setSignupResult(result);
      setStep(2);
      onStepChange?.(2);
    } catch (err: any) {
      logger.error('Sign up error', err);
      toast.error(err?.message ?? 'Error creating account');
      onError?.(err);
    }
  };

  // Step 2: Verification → Verify OTP → Step 3 (Plan selection)
  if (step === 2 && signupResult) {
    const handleVerify = async (code: string) => {
      try {
        await verifyOtp(signupResult.email, code, 'signup', config.productId);
        logger.info('Email verified successfully, moving to plan selection');
        toast.success('Email verified successfully');
        // Move to plan selection after verification
        setStep(3);
        onStepChange?.(3);
      } catch (err: any) {
        logger.error('Verification error', err);
        toast.error(err?.message ?? 'Error verifying code');
        throw err; // Let VerificationRequired handle the error display
      }
    };

    const handleResend = async () => {
      try {
        await supabase.auth.resend({
          type: 'signup',
          email: signupResult.email,
        });
      } catch (err) {
        logger.error('Resend error', err);
        throw err;
      }
    };

    return (
      <div className={cn('idp-space-y-6', className)}>
        <VerificationRequired
          email={signupResult.email}
          onVerify={handleVerify}
          onResend={handleResend}
          type="signup"
          loading={verifyingOtp}
          error={verifyError?.message || null}
        />
      </div>
    );
  }

  // Step 3: Plan Selection → Complete signup (create org/subscription)
  const handlePlanSignUp = async (planId: string, productPlanId: string) => {
    if (hasValidationError || !config.productId) {
      const err = new Error('Product ID is not configured');
      logger.error('Signup configuration error', err);
      toast.error('Product not configured');
      onError?.(err);
      return;
    }

    try {
      // Complete signup: create org and subscription
      const result = await completeSignup({
        productId: config.productId,
        planId,
        billingInterval: selectedBillingInterval,
        orgName: formData.useUserName ? undefined : formData.orgName,
        useUserName: formData.useUserName,
      });

      logger.info('Signup completed successfully', result);
      toast.success('Sign up completed successfully');
      onSuccess?.({
        orgId: result.orgId,
        subscriptionId: result.subscriptionId,
        status: result.status,
      });
    } catch (err: any) {
      logger.error('Complete signup error', err);
      toast.error(err?.message ?? 'Error completing sign up');
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

        <div className="idp-space-y-2">
          <Label htmlFor="confirmPassword">Confirm Password</Label>
          <Input
            id="confirmPassword"
            type="password"
            value={formData.confirmPassword}
            onChange={(e) => setFormData(prev => ({ ...prev, confirmPassword: e.target.value }))}
            required
            disabled={isDisabled}
            placeholder="Confirm your password"
            minLength={6}
          />
          {formData.confirmPassword && formData.password !== formData.confirmPassword && (
            <p className="idp-text-xs idp-text-red-600 dark:idp-text-red-400">
              Passwords do not match
            </p>
          )}
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
        {currentError && !hasValidationError && (
          <Alert variant="destructive">
            <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
            <AlertDescription>{currentError.message}</AlertDescription>
          </Alert>
        )}

        <Button
          type="submit"
          disabled={isDisabled}
          className="idp-w-full"
        >
          {signUpLoading ? 'Creating account...' : isValidating ? 'Validating...' : 'Continue'}
        </Button>
      </form>
    );
  }

  // Step 3: Plan Selection with Cards
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
          setStep(2);
          onStepChange?.(2);
        }}
        disabled={completeLoading}
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

        {/* Billing Interval Selector */}
        {availablePlans.length > 0 && billingIntervals.length > 0 && (
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
                    completeLoading && 'idp-opacity-50 idp-pointer-events-none'
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
                      disabled={completeLoading || isDisabled}
                      className={cn('idp-w-full idp-text-white idp-font-semibold', colorScheme.button)}
                      size="lg"
                    >
                      {completeLoading ? 'Completing signup...' : 'Choose'}
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
      {currentError && !hasValidationError && (
        <Alert variant="destructive">
          <Icon icon={AlertCircle} className="idp-h-4 idp-w-4" />
          <AlertDescription>{currentError.message}</AlertDescription>
        </Alert>
      )}
    </div>
  );
};
