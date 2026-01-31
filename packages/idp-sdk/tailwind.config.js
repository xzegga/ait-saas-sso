import tailwindcssAnimate from 'tailwindcss-animate';

/** @type {import('tailwindcss').Config} */
export default {
  darkMode: ['class'],
  content: [
    './src/**/*.{ts,tsx}',
  ],
  prefix: 'idp-',
  theme: {
    container: {
      center: true,
      padding: '2rem',
      screens: {
        '2xl': '1400px',
      },
    },
    extend: {
      colors: {
        border: 'hsl(var(--idp-border) / <alpha-value>)',
        input: 'hsl(var(--idp-input) / <alpha-value>)',
        ring: 'hsl(var(--idp-ring) / <alpha-value>)',
        background: 'hsl(var(--idp-background) / <alpha-value>)',
        foreground: 'hsl(var(--idp-foreground) / <alpha-value>)',
        primary: {
          DEFAULT: 'hsl(var(--idp-primary) / <alpha-value>)',
          foreground: 'hsl(var(--idp-primary-foreground) / <alpha-value>)',
        },
        secondary: {
          DEFAULT: 'hsl(var(--idp-secondary) / <alpha-value>)',
          foreground: 'hsl(var(--idp-secondary-foreground) / <alpha-value>)',
        },
        destructive: {
          DEFAULT: 'hsl(var(--idp-destructive) / <alpha-value>)',
          foreground: 'hsl(var(--idp-destructive-foreground) / <alpha-value>)',
        },
        muted: {
          DEFAULT: 'hsl(var(--idp-muted) / <alpha-value>)',
          foreground: 'hsl(var(--idp-muted-foreground) / <alpha-value>)',
        },
        accent: {
          DEFAULT: 'hsl(var(--idp-accent) / <alpha-value>)',
          foreground: 'hsl(var(--idp-accent-foreground) / <alpha-value>)',
        },
        popover: {
          DEFAULT: 'hsl(var(--idp-popover) / <alpha-value>)',
          foreground: 'hsl(var(--idp-popover-foreground) / <alpha-value>)',
        },
        card: {
          DEFAULT: 'hsl(var(--idp-card) / <alpha-value>)',
          foreground: 'hsl(var(--idp-card-foreground) / <alpha-value>)',
        },
      },
      borderRadius: {
        lg: 'var(--idp-radius)',
        md: 'calc(var(--idp-radius) - 2px)',
        sm: 'calc(var(--idp-radius) - 4px)',
      },
      keyframes: {
        'accordion-down': {
          from: { height: '0' },
          to: { height: 'var(--radix-accordion-content-height)' },
        },
        'accordion-up': {
          from: { height: 'var(--radix-accordion-content-height)' },
          to: { height: '0' },
        },
      },
      animation: {
        'accordion-down': 'accordion-down 0.2s ease-out',
        'accordion-up': 'accordion-up 0.2s ease-out',
      },
    },
  },
  plugins: [tailwindcssAnimate],
};
