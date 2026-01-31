/**
 * Custom error classes for the IDP SDK
 */

export class IDPError extends Error {
  constructor(
    message: string,
    public code?: string,
    public statusCode?: number
  ) {
    super(message);
    this.name = 'IDPError';
    Object.setPrototypeOf(this, IDPError.prototype);
  }
}

export class AuthenticationError extends IDPError {
  constructor(message: string = 'Authentication failed', statusCode?: number) {
    super(message, 'AUTH_ERROR', statusCode || 401);
    this.name = 'AuthenticationError';
    Object.setPrototypeOf(this, AuthenticationError.prototype);
  }
}

export class AuthorizationError extends IDPError {
  constructor(message: string = 'Access denied', statusCode?: number) {
    super(message, 'AUTHORIZATION_ERROR', statusCode || 403);
    this.name = 'AuthorizationError';
    Object.setPrototypeOf(this, AuthorizationError.prototype);
  }
}

export class ValidationError extends IDPError {
  constructor(message: string = 'Validation failed', statusCode?: number) {
    super(message, 'VALIDATION_ERROR', statusCode || 400);
    this.name = 'ValidationError';
    Object.setPrototypeOf(this, ValidationError.prototype);
  }
}

export class NetworkError extends IDPError {
  constructor(message: string = 'Network request failed', statusCode?: number) {
    super(message, 'NETWORK_ERROR', statusCode || 0);
    this.name = 'NetworkError';
    Object.setPrototypeOf(this, NetworkError.prototype);
  }
}

export class ConfigurationError extends IDPError {
  constructor(message: string = 'Configuration error') {
    super(message, 'CONFIGURATION_ERROR', 500);
    this.name = 'ConfigurationError';
    Object.setPrototypeOf(this, ConfigurationError.prototype);
  }
}
