import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

/**
 * Utility function to merge Tailwind CSS classes
 * Allows consumers to override styles by passing className props
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
