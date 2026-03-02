/**
 * OTP Input Component
 * 
 * A component for entering 6-digit OTP codes with individual input fields
 * Uses SDK design patterns and styles
 */

import React, { useRef, useEffect, useState } from 'react';
import { cn } from '@/lib/utils';

export interface OTPInputProps {
  length?: number;
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
  error?: boolean;
  autoFocus?: boolean;
  className?: string;
}

export const OTPInput: React.FC<OTPInputProps> = ({
  length = 6,
  value,
  onChange,
  disabled = false,
  error = false,
  autoFocus = true,
  className = '',
}) => {
  const [otp, setOtp] = useState<string[]>(new Array(length).fill(''));
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => {
    // Sync external value with internal state
    if (value) {
      const valueArray = value.split('').slice(0, length);
      const newOtp = [...otp];
      valueArray.forEach((char, index) => {
        if (index < length) {
          newOtp[index] = char;
        }
      });
      setOtp(newOtp);
    } else {
      setOtp(new Array(length).fill(''));
    }
  }, [value, length]);

  const handleChange = (index: number, newValue: string) => {
    // Only allow digits
    if (newValue && !/^\d$/.test(newValue)) {
      return;
    }

    const newOtp = [...otp];
    newOtp[index] = newValue;
    setOtp(newOtp);

    // Call onChange with the complete OTP string
    const otpString = newOtp.join('');
    onChange(otpString);

    // Auto-focus next input
    if (newValue && index < length - 1) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    // Handle backspace
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
    // Handle paste
    if (e.key === 'v' && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      navigator.clipboard.readText().then((text) => {
        const digits = text.replace(/\D/g, '').slice(0, length);
        const newOtp = [...otp];
        digits.split('').forEach((digit, i) => {
          if (index + i < length) {
            newOtp[index + i] = digit;
          }
        });
        setOtp(newOtp);
        onChange(newOtp.join(''));
        const nextIndex = Math.min(index + digits.length, length - 1);
        inputRefs.current[nextIndex]?.focus();
      });
    }
  };

  const handleFocus = (index: number) => {
    inputRefs.current[index]?.select();
  };

  useEffect(() => {
    if (autoFocus && inputRefs.current[0]) {
      inputRefs.current[0].focus();
    }
  }, [autoFocus]);

  return (
    <div className={cn('idp-flex idp-gap-2 idp-justify-center', className)}>
      {otp.map((digit, index) => (
        <input
          key={index}
          ref={(el) => (inputRefs.current[index] = el)}
          type="text"
          inputMode="numeric"
          maxLength={1}
          value={digit}
          onChange={(e) => handleChange(index, e.target.value)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          onFocus={() => handleFocus(index)}
          disabled={disabled}
          className={cn(
            'idp-w-12 idp-h-12 idp-text-center idp-text-lg idp-font-semibold',
            'idp-border-2 idp-rounded-md',
            'focus:idp-outline-none focus:idp-ring-2 focus:idp-ring-blue-500 focus:idp-ring-offset-2',
            'idp-transition-colors',
            error 
              ? 'idp-border-red-500 dark:idp-border-red-400 idp-bg-red-50 dark:idp-bg-red-900/20' 
              : 'idp-border-input idp-bg-background',
            disabled 
              ? 'idp-bg-muted idp-cursor-not-allowed idp-opacity-50' 
              : 'hover:idp-border-blue-400 dark:hover:idp-border-blue-600',
            'idp-text-foreground'
          )}
          aria-label={`Digit ${index + 1} of ${length}`}
        />
      ))}
    </div>
  );
};
