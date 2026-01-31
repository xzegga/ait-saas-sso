/**
 * Utility functions for the IDP SDK
 */

import type { JWTPayload } from './types';

/**
 * Parse JWT token and extract payload
 */
export function parseJWT(token: string): JWTPayload | null {
  try {
    const base64Url = token.split('.')[1];
    if (!base64Url) return null;
    
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    
    return JSON.parse(jsonPayload);
  } catch (error) {
    return null;
  }
}

/**
 * Extract permissions from JWT payload
 */
export function extractPermissions(payload: JWTPayload): string[] {
  return payload.permissions || [];
}

/**
 * Extract roles from JWT payload
 */
export function extractRoles(payload: JWTPayload): string[] {
  const roles: string[] = [];
  if (payload.role) {
    roles.push(payload.role);
  }
  // Add any additional role extraction logic here
  return roles;
}

/**
 * Check if user has a specific permission
 */
export function hasPermission(payload: JWTPayload | null, permission: string): boolean {
  if (!payload) return false;
  const permissions = extractPermissions(payload);
  return permissions.includes(permission);
}

/**
 * Check if user has a specific role
 */
export function hasRole(payload: JWTPayload | null, role: string): boolean {
  if (!payload) return false;
  const roles = extractRoles(payload);
  return roles.includes(role);
}

/**
 * Get organization ID from JWT payload
 */
export function getOrganizationId(payload: JWTPayload | null): string | null {
  if (!payload) return null;
  return payload.org_id || null;
}

/**
 * Format date to ISO string
 */
export function formatDate(date: string | Date | null | undefined): string | null {
  if (!date) return null;
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toISOString();
}

/**
 * Validate email format
 */
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Debounce function
 */
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: ReturnType<typeof setTimeout> | null = null;
  
  return function executedFunction(...args: Parameters<T>) {
    const later = () => {
      timeout = null;
      func(...args);
    };
    
    if (timeout) {
      clearTimeout(timeout);
    }
    timeout = setTimeout(later, wait);
  };
}
