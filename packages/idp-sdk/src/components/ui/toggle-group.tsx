import * as React from 'react';
import * as ToggleGroupPrimitive from '@radix-ui/react-toggle-group';
import { cn } from '@/lib/utils';

const ToggleGroup = React.forwardRef<
  React.ElementRef<typeof ToggleGroupPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof ToggleGroupPrimitive.Root>
>(({ className, ...props }, ref) => (
  <ToggleGroupPrimitive.Root
    ref={ref}
    className={cn(
      'idp-inline-flex idp-items-center idp-justify-center idp-rounded-md idp-bg-muted idp-p-1 idp-text-muted-foreground',
      className
    )}
    {...props}
  />
));
ToggleGroup.displayName = ToggleGroupPrimitive.Root.displayName;

const ToggleGroupItem = React.forwardRef<
  React.ElementRef<typeof ToggleGroupPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof ToggleGroupPrimitive.Item>
>(({ className, ...props }, ref) => (
  <ToggleGroupPrimitive.Item
    ref={ref}
    className={cn(
      'idp-inline-flex idp-items-center idp-justify-center idp-rounded-sm idp-px-3 idp-py-1.5 idp-text-sm idp-font-medium idp-ring-offset-background idp-transition-all focus-visible:idp-outline-none focus-visible:idp-ring-2 focus-visible:idp-ring-ring focus-visible:idp-ring-offset-2 disabled:idp-pointer-events-none disabled:idp-opacity-50 data-[state=on]:idp-bg-background data-[state=on]:idp-text-foreground data-[state=on]:idp-shadow-sm',
      className
    )}
    {...props}
  />
));
ToggleGroupItem.displayName = ToggleGroupPrimitive.Item.displayName;

export { ToggleGroup, ToggleGroupItem };
