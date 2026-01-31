# Logger Documentation

## Overview

The logger utility provides a centralized logging system with configurable log levels and environment-based defaults.

## Log Levels

The logger supports four log levels (from most to least verbose):

- **debug**: Detailed information for debugging (most verbose)
- **info**: General informational messages
- **warn**: Warning messages
- **error**: Error messages (least verbose)

Only messages at or above the current log level will be displayed.

## Usage

```typescript
import { logger } from '@/lib/logger';

// Debug messages (only shown in development or when log level is 'debug')
logger.debug('Processing user data', { userId: '123', action: 'update' });

// Info messages
logger.info('User logged in successfully');

// Warning messages
logger.warn('API rate limit approaching', { remaining: 10 });

// Error messages
logger.error('Failed to save data', error);
```

## Configuration

### Environment Variables

Add these variables to your `.env.development` or `.env.production` file:

```env
# Log level: 'debug' | 'info' | 'warn' | 'error'
# Default: 'debug' in development, 'warn' in production
VITE_LOG_LEVEL=debug

# Enable/disable logging: 'true' | 'false'
# Default: 'true'
VITE_LOG_ENABLED=true
```

### Runtime Configuration

You can also configure the logger at runtime:

```typescript
import { logger } from '@/lib/logger';

// Change log level
logger.setLevel('info');

// Disable logging
logger.setEnabled(false);

// Enable logging
logger.setEnabled(true);

// Get current level
const currentLevel = logger.getLevel();

// Check if enabled
const isEnabled = logger.isEnabled();
```

## Default Behavior

- **Development mode**: Log level defaults to `'debug'` (shows all logs)
- **Production mode**: Log level defaults to `'warn'` (only shows warnings and errors)
- **Logging is enabled by default** unless `VITE_LOG_ENABLED=false`

## Examples

### Basic Usage

```typescript
import { logger } from '@/lib/logger';

function processPayment(amount: number) {
  logger.debug('Processing payment', { amount });
  
  try {
    // Payment logic
    logger.info('Payment processed successfully');
  } catch (error) {
    logger.error('Payment failed', error);
    throw error;
  }
}
```

### Conditional Logging

```typescript
import { logger } from '@/lib/logger';

function fetchData() {
  if (logger.isEnabled() && logger.getLevel() === 'debug') {
    logger.debug('Fetching data from API');
  }
  
  // Your code here
}
```

## Best Practices

1. **Use appropriate log levels**:
   - `debug`: For detailed debugging information
   - `info`: For important events (user actions, successful operations)
   - `warn`: For potential issues that don't break functionality
   - `error`: For actual errors that need attention

2. **Don't log sensitive information**:
   - Avoid logging passwords, tokens, or personal data
   - Use `debug` level for detailed data, not `info` or higher

3. **Use structured logging**:
   - Pass objects as additional arguments for better debugging
   - Example: `logger.debug('User action', { userId, action, timestamp })`

4. **Production considerations**:
   - Default to `'warn'` level in production
   - Consider disabling logging entirely in production if not needed
   - Use error tracking services (Sentry, etc.) for production errors
