import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'idp-inline-flex idp-items-center idp-justify-center idp-whitespace-nowrap idp-rounded-md idp-text-sm idp-font-medium idp-ring-offset-background idp-transition-colors focus-visible:idp-outline-none focus-visible:idp-ring-2 focus-visible:idp-ring-ring focus-visible:idp-ring-offset-2 disabled:idp-pointer-events-none disabled:idp-opacity-50',
  {
    variants: {
      variant: {
        default: 'idp-bg-primary idp-text-primary-foreground hover:idp-bg-primary/90',
        destructive: 'idp-bg-destructive idp-text-destructive-foreground hover:idp-bg-destructive/90',
        outline: 'idp-border idp-border-input idp-bg-background hover:idp-bg-accent hover:idp-text-accent-foreground',
        secondary: 'idp-bg-secondary idp-text-secondary-foreground hover:idp-bg-secondary/80',
        ghost: 'hover:idp-bg-accent hover:idp-text-accent-foreground',
        link: 'idp-text-primary idp-underline-offset-4 hover:idp-underline',
      },
      size: {
        default: 'idp-h-10 idp-px-4 idp-py-2',
        sm: 'idp-h-9 idp-rounded-md idp-px-3',
        lg: 'idp-h-11 idp-rounded-md idp-px-8',
        icon: 'idp-h-10 idp-w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(buttonVariants({ variant, size }), className)}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
