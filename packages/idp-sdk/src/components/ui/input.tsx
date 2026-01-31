import * as React from 'react';
import { cn } from '@/lib/utils';

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          'idp-flex idp-h-10 idp-w-full idp-rounded-md idp-border idp-border-input idp-bg-background idp-px-3 idp-py-2 idp-text-sm idp-ring-offset-background file:idp-border-0 file:idp-bg-transparent file:idp-text-sm file:idp-font-medium placeholder:idp-text-muted-foreground focus-visible:idp-outline-none focus-visible:idp-ring-2 focus-visible:idp-ring-ring focus-visible:idp-ring-offset-2 disabled:idp-cursor-not-allowed disabled:idp-opacity-50',
          className
        )}
        ref={ref}
        {...props}
      />
    );
  }
);
Input.displayName = 'Input';

export { Input };
