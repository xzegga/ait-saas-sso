import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { IDPProvider, AuthProvider, AuthGuard } from '@ait-saas-sso/idp-sdk';
import { SUPABASE_URL, SUPABASE_ANON_KEY, PRODUCT_ID, CLIENT_SECRET } from './config/supabase';
import { Layout } from './components/Layout';
import { HomePage } from './pages/HomePage';
import { LoginPage } from './pages/LoginPage';
import { SignUpPage } from './pages/SignUpPage';
import { ForgotPasswordPage } from './pages/ForgotPasswordPage';
import { DashboardPage } from './pages/DashboardPage';
import { ProfilePage } from './pages/ProfilePage';
import { OrganizationPage } from './pages/OrganizationPage';
import { BillingPage } from './pages/BillingPage';
import './App.css';

function App() {
  return (
    <IDPProvider
      supabaseUrl={SUPABASE_URL}
      supabaseAnonKey={SUPABASE_ANON_KEY}
      productId={PRODUCT_ID || undefined}
      clientSecret={CLIENT_SECRET || undefined}
    >
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/signup" element={<SignUpPage />} />
            <Route path="/forgot-password" element={<ForgotPasswordPage />} />
            
            {/* Protected routes */}
            <Route
              path="/dashboard"
              element={
                <AuthGuard redirectTo="/login">
                  <Layout>
                    <DashboardPage />
                  </Layout>
                </AuthGuard>
              }
            />
            <Route
              path="/profile"
              element={
                <AuthGuard redirectTo="/login">
                  <Layout>
                    <ProfilePage />
                  </Layout>
                </AuthGuard>
              }
            />
            <Route
              path="/organization"
              element={
                <AuthGuard redirectTo="/login">
                  <Layout>
                    <OrganizationPage />
                  </Layout>
                </AuthGuard>
              }
            />
            <Route
              path="/billing"
              element={
                <AuthGuard redirectTo="/login">
                  <Layout>
                    <BillingPage />
                  </Layout>
                </AuthGuard>
              }
            />
            
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </IDPProvider>
  );
}

export default App;
