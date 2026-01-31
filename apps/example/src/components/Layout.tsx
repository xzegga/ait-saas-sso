import { ReactNode } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { UserMenu, useLogout } from '@ait-saas-sso/idp-sdk';

interface LayoutProps {
  children: ReactNode;
}

export const Layout = ({ children }: LayoutProps) => {
  const navigate = useNavigate();
  const { logout } = useLogout();

  const handleLogout = async () => {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
      navigate('/login');
    }
  };

  return (
    <div className="app-layout">
      <header className="app-header">
        <div className="app-header-content">
          <Link to="/dashboard" className="app-logo">
            IDP SDK Demo
          </Link>
          <nav className="app-nav">
            <Link to="/dashboard">Dashboard</Link>
            <Link to="/profile">Profile</Link>
            <Link to="/organization">Organization</Link>
            <Link to="/billing">Billing</Link>
          </nav>
          <div className="app-header-actions">
            <UserMenu onLogout={handleLogout} />
          </div>
        </div>
      </header>
      <main className="app-main">
        {children}
      </main>
    </div>
  );
};
