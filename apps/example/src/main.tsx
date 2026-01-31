import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@ait-saas-sso/idp-sdk/style.css';
import './index.css';
import App from './App.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
);
