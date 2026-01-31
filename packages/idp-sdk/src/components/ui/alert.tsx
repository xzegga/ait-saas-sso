import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const alertVariants = cva(
  'idp-relative idp-w-full idp-rounded-lg idp-border idp-p-4 [&>svg~*]:idp-pl-7 [&>svg+div]:idp-translate-y-[-3px] [&>svg]:idp-absolute [&>svg]:idp-left-4 [&>svg]:idp-top-4 [&>svg]:idp-text-foreground',
  {
    variants: {
      variant: {
        default: 'idp-bg-background idp-text-foreground',
        destructive:
          'idp-border-destructive/50 idp-text-destructive dark:idp-border-destructive [&>svg]:idp-text-destructive',
        warning:
          'idp-border-yellow-500/50 idp-bg-yellow-50 idp-text-yellow-800 dark:idp-bg-yellow-950 dark:idp-text-yellow-200 [&>svg]:idp-text-yellow-600',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  }
);

const Alert = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement> & VariantProps<typeof alertVariants>
>(({ className, variant, ...props }, ref) => (
  <div
    ref={ref}
    role="alert"
    className={cn(alertVariants({ variant }), className)}
    {...props}
  />
));
Alert.displayName = 'Alert';

const AlertTitle = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLHeadingElement>
>(({ className, ...props }, ref) => (
  <h5
    ref={ref}
    className={cn('idp-mb-1 idp-font-medium idp-leading-none idp-tracking-tight', className)}
    {...props}
  />
));
AlertTitle.displayName = 'AlertTitle';

const AlertDescription = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLParagraphElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn('idp-text-sm [&_p]:idp-leading-relaxed', className)}
    {...props}
  />
));
AlertDescription.displayName = 'AlertDescription';

export { Alert, AlertTitle, AlertDescription };
