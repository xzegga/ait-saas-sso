/**
 * Logger utility for the IDP SDK
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}

const LOG_LEVEL_MAP: Record<string, LogLevel> = {
  debug: LogLevel.DEBUG,
  info: LogLevel.INFO,
  warn: LogLevel.WARN,
  error: LogLevel.ERROR,
};

// Extend Window interface for IDP SDK configuration
declare global {
  interface Window {
    __IDP_LOG_LEVEL__?: string;
    __IDP_LOG_ENABLED?: string;
  }
}

const DEFAULT_LOG_LEVEL = typeof process !== 'undefined' && process.env.NODE_ENV === 'development' 
  ? LogLevel.DEBUG 
  : LogLevel.WARN;

const configuredLogLevel = typeof window !== 'undefined' && window.__IDP_LOG_LEVEL__
  ? LOG_LEVEL_MAP[window.__IDP_LOG_LEVEL__.toLowerCase()] ?? DEFAULT_LOG_LEVEL
  : DEFAULT_LOG_LEVEL;

const isLoggingEnabled = typeof window === 'undefined' || window.__IDP_LOG_ENABLED !== 'false';

const log = (level: LogLevel, message: string, ...args: unknown[]) => {
  if (!isLoggingEnabled || level < configuredLogLevel) {
    return;
  }
  const timestamp = new Date().toISOString();
  const prefix = `[${timestamp}] [IDP-SDK] [${LogLevel[level]}]`;

  switch (level) {
    case LogLevel.DEBUG:
      console.debug(prefix, message, ...args);
      break;
    case LogLevel.INFO:
      console.info(prefix, message, ...args);
      break;
    case LogLevel.WARN:
      console.warn(prefix, message, ...args);
      break;
    case LogLevel.ERROR:
      console.error(prefix, message, ...args);
      break;
    default:
      console.log(prefix, message, ...args);
  }
};

export const logger = {
  debug: (message: string, ...args: unknown[]) => log(LogLevel.DEBUG, message, ...args),
  info: (message: string, ...args: unknown[]) => log(LogLevel.INFO, message, ...args),
  warn: (message: string, ...args: unknown[]) => log(LogLevel.WARN, message, ...args),
  error: (message: string, ...args: unknown[]) => log(LogLevel.ERROR, message, ...args),
};
