/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
    './node_modules/@ait-saas-sso/idp-sdk/dist/**/*.js',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
