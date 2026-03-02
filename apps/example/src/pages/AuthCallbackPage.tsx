import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '@ait-saas-sso/idp-sdk';

/**
 * Auth Callback Page
 * 
 * This page handles email confirmation callbacks from Supabase Auth.
 * When a user clicks the confirmation link in their email, Supabase redirects here
 * with token and type parameters. We then verify the token to confirm the email.
 * 
 * Reference: https://supabase.com/docs/reference/javascript/auth-api
 */
export function AuthCallbackPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { supabase } = useAuth();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('Verifying your email...');

  useEffect(() => {
    const verifyEmail = async () => {
      try {
        // Supabase Auth callbacks can have tokens in query params or hash fragments
        // Check both locations
        const tokenFromQuery = searchParams.get('token');
        const typeFromQuery = searchParams.get('type');
        
        // Also check hash fragments (Supabase sometimes uses these)
        const hash = window.location.hash.substring(1);
        const hashParams = new URLSearchParams(hash);
        const tokenFromHash = hashParams.get('access_token') || hashParams.get('token');
        const typeFromHash = hashParams.get('type');
        
        // Use token from query params first, then hash
        const token = tokenFromQuery || tokenFromHash;
        const type = typeFromQuery || typeFromHash || 'signup';
        
        console.log('Auth callback params:', {
          tokenFromQuery,
          tokenFromHash,
          type,
          hash,
          fullUrl: window.location.href,
        });
        
        if (!token) {
          setStatus('error');
          setMessage('No verification token found in the link. Please check your email for a valid confirmation link.');
          setTimeout(() => navigate('/login'), 5000);
          return;
        }

        // According to Supabase Auth API docs:
        // - For email confirmation links, we use verifyOtp with token_hash
        // - The token from the URL should be used as token_hash
        // - Type should be 'signup' for signup confirmations or 'email' for email changes
        const { data, error } = await supabase.auth.verifyOtp({
          token_hash: token,
          type: type === 'signup' ? 'signup' : 'email',
        });

        if (error) {
          console.error('Email verification error:', error);
          setStatus('error');
          setMessage(error.message || 'Failed to verify your email. The link may have expired or already been used.');
          setTimeout(() => navigate('/login'), 5000);
          return;
        }

        if (data.user) {
          setStatus('success');
          setMessage('Email verified successfully! Redirecting to dashboard...');
          // Redirect to dashboard after successful verification
          setTimeout(() => navigate('/dashboard'), 2000);
        } else {
          setStatus('error');
          setMessage('Verification completed but no user session was created.');
          setTimeout(() => navigate('/login'), 3000);
        }
      } catch (err) {
        console.error('Unexpected error during email verification:', err);
        setStatus('error');
        setMessage('An unexpected error occurred. Please try again or contact support.');
        setTimeout(() => navigate('/login'), 3000);
      }
    };

    verifyEmail();
  }, [searchParams, navigate, supabase]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8">
        <div className="text-center">
          {status === 'loading' && (
            <>
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
              <h2 className="text-2xl font-bold text-gray-900">Verifying Email</h2>
              <p className="mt-2 text-gray-600">{message}</p>
            </>
          )}
          
          {status === 'success' && (
            <>
              <div className="rounded-full h-12 w-12 bg-green-100 flex items-center justify-center mx-auto mb-4">
                <svg className="h-6 w-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Email Verified!</h2>
              <p className="mt-2 text-gray-600">{message}</p>
            </>
          )}
          
          {status === 'error' && (
            <>
              <div className="rounded-full h-12 w-12 bg-red-100 flex items-center justify-center mx-auto mb-4">
                <svg className="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Verification Failed</h2>
              <p className="mt-2 text-gray-600">{message}</p>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
