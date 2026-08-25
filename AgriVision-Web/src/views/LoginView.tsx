import React, { useState } from 'react';
import { useAuth } from '../core/auth/AuthContext';
import { GlassCard } from '../components/ui/GlassCard';
import { ShieldCheck, Link2, LogIn, Sparkles } from 'lucide-react';
import { GoogleAuthProvider } from 'firebase/auth';

// A simple utility to extract a user-friendly error message
const getErrorMessage = (error: any): string => {
  if (error && error.code === 'auth/account-exists-with-different-credential') {
    return 'An account already exists with this email using a different sign-in method. Please use your email and password.';
  }
  if (error instanceof Error) {
    if (error.message.includes('auth/account-exists-with-different-credential') || error.message.includes('auth/email-already-in-use')) {
      return 'An account already exists with this email using a different sign-in method. Please use your email and password.';
    }
    // Specifically handle Firebase or network errors safely without exposing raw stacks
    if (error.message.includes('auth/')) {
      return 'Authentication failed. Please check your credentials and try again.';
    }
    return error.message;
  }
  if (error && typeof error.code === 'string' && error.code.includes('auth/')) {
    return 'Authentication failed. Please check your credentials and try again.';
  }
  return 'An unexpected error occurred. Please try again.';
};

export const LoginView: React.FC = () => {
  const { signInWithEmail, signInGoogle, linkGoogleAccount, loading, authError } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);

  React.useEffect(() => {
    if (authError) {
      setError(authError);
    }
  }, [authError]);

  // Linking state
  const [linkEmail, setLinkEmail] = useState<string | null>(null);
  const [linkCredential, setLinkCredential] = useState<any>(null);

  const handleEmailSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;
    try {
      setError(null);
      await signInWithEmail(email, password);
    } catch (err: unknown) {
      setError(getErrorMessage(err));
    }
  };

  const handleGoogleSignIn = async () => {
    try {
      setError(null);
      await signInGoogle();
    } catch (err: any) {
      if (err && err.code === 'auth/account-exists-with-different-credential') {
        const pendingEmail = err.customData?.email;
        const pendingCred = GoogleAuthProvider.credentialFromError(err);
        if (pendingEmail && pendingCred) {
          setLinkEmail(pendingEmail);
          setLinkCredential(pendingCred);
          setError(null);
          return;
        }
      }
      const msg = getErrorMessage(err);
      setError(msg);
    }
  };

  const handleLinkSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!linkEmail || !password || !linkCredential) return;
    try {
      setError(null);
      await linkGoogleAccount(linkEmail, password, linkCredential);
    } catch (err: unknown) {
      setError(getErrorMessage(err));
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-[radial-gradient(circle_at_50%_30%,rgba(34,78,40,0.6)_0%,rgba(10,23,13,0.98)_70%)]">
      <div className="w-full max-w-[440px]">
        <GlassCard glow className="p-10">
          {/* Brand Header */}
          <div className="flex items-center gap-3.5 mb-7">
            <img
              src="/logo.png"
              alt="AgriVision Logo"
              className="w-[52px] h-[52px] object-contain rounded-xl drop-shadow-[0_0_10px_rgba(176,209,130,0.4)]"
            />
            <div>
              <h1 className="text-2xl font-extrabold text-text-main tracking-tight">
                AgriVision
              </h1>
              <p className="text-xs text-primary-light font-semibold">
                Staff Command Portal
              </p>
            </div>
          </div>

          {/* Error Display */}
          {error && (
            <div className="p-3 bg-accent-red/15 border border-accent-red/35 rounded-lg text-red-300 text-xs mb-4 leading-relaxed" role="alert">
              {error}
            </div>
          )}

          {linkEmail ? (
            /* Linking Form */
            <form onSubmit={handleLinkSubmit} className="flex flex-col gap-3.5">
              <div className="flex items-start gap-2 p-3 bg-primary-medium/20 border border-primary-light/30 rounded-lg mb-2">
                <Link2 size={16} className="text-primary-light shrink-0 mt-0.5" />
                <p className="text-[11px] text-text-muted leading-relaxed">
                  An account with <strong>{linkEmail}</strong> already exists. Please enter your password to link your Google account to it securely.
                </p>
              </div>

              <div>
                <label className="text-[11px] font-semibold text-text-muted mb-1 block">Email Address</label>
                <input
                  type="email"
                  disabled
                  value={linkEmail}
                  className="w-full px-3.5 py-2.5 rounded-sm bg-black/40 border border-border-glass/50 text-text-dim text-sm outline-none cursor-not-allowed"
                />
              </div>

              <div>
                <label className="text-[11px] font-semibold text-text-muted mb-1 block">Password</label>
                <input
                  type="password"
                  required
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="btn-primary w-full justify-center mt-1.5 py-3 disabled:opacity-70 disabled:cursor-not-allowed"
              >
                <Link2 size={16} />
                <span>{loading ? 'Linking Account...' : 'Link Google Account'}</span>
              </button>
              
              <button
                type="button"
                onClick={() => { setLinkEmail(null); setLinkCredential(null); setPassword(''); }}
                disabled={loading}
                className="text-xs text-text-dim hover:text-white transition-colors mt-3 text-center w-full"
              >
                Cancel and return to sign in
              </button>
            </form>
          ) : (
            /* Standard Login Form */
            <>
              {/* Access Notice */}
              <div className="flex items-start gap-2 p-3 bg-[rgba(154,212,108,0.08)] border border-[rgba(154,212,108,0.2)] rounded-lg mb-6">
                <ShieldCheck size={16} className="text-primary-light shrink-0 mt-0.5" />
                <p className="text-[11px] text-text-muted leading-relaxed">
                  Access restricted to authorized staff only. Sign in with your registered credentials or Google account.
                </p>
              </div>

              <form onSubmit={handleEmailSubmit} className="flex flex-col gap-3.5">
                <div>
                  <label className="text-[11px] font-semibold text-text-muted mb-1 block">Email Address</label>
                  <input
                    type="email"
                    required
                    placeholder="you@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    autoComplete="email"
                    className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                  />
                </div>

                <div>
                  <label className="text-[11px] font-semibold text-text-muted mb-1 block">Password</label>
                  <input
                    type="password"
                    required
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    autoComplete="current-password"
                    className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="btn-primary w-full justify-center mt-1.5 py-3 disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  <LogIn size={16} />
                  <span>{loading ? 'Authenticating...' : 'Sign In'}</span>
                </button>
              </form>

              {/* Divider */}
              <div className="flex items-center gap-3 my-5">
                <div className="flex-1 h-px bg-border-subtle" />
                <span className="text-[11px] text-text-dim">OR</span>
                <div className="flex-1 h-px bg-border-subtle" />
              </div>

              {/* Google Sign-In */}
              <button
                onClick={handleGoogleSignIn}
                disabled={loading}
                className="btn-secondary w-full justify-center py-3 disabled:opacity-70 disabled:cursor-not-allowed"
              >
                <Sparkles size={16} className="text-accent-lime" />
                <span>Sign in with Google</span>
              </button>

              {/* Footer */}
              <p className="text-[11px] text-text-dim text-center mt-6 leading-relaxed">
                Only invited staff can access the web portal.<br />
                Farmers can use the AgriVision iOS app.
              </p>
            </>
          )}
        </GlassCard>
      </div>
    </div>
  );
};
