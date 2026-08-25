import React, { useEffect, useState } from 'react';
import { useAuth } from '../core/auth/AuthContext';
import { GlassCard } from '../components/ui/GlassCard';
import { CheckCircle2, ShieldCheck, Lock, User, AlertCircle, ArrowRight } from 'lucide-react';
import { auth } from '../core/auth/firebase';
import { isSignInWithEmailLink } from 'firebase/auth';

export const InviteAcceptView: React.FC = () => {
  const { completeSignInWithLink, registerInvitedUser, initialLoad } = useAuth();
  
  const [step, setStep] = useState<'verifying' | 'prompt_email' | 'set_password' | 'success' | 'error'>('verifying');
  const [email, setEmail] = useState<string>('');
  const [displayName, setDisplayName] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [confirmPassword, setConfirmPassword] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [assignedRole, setAssignedRole] = useState<string>('staff');

  useEffect(() => {
    if (initialLoad) return; // Wait for Firebase to restore any existing session

    const checkLink = async () => {
      const url = window.location.href;
      if (!isSignInWithEmailLink(auth, url)) {
        setStep('error');
        setErrorMessage('This URL is not a valid AgriVision invitation link or has already expired.');
        return;
      }

      let savedEmail = window.localStorage.getItem('emailForSignIn');
      if (!savedEmail) {
        setStep('prompt_email');
        return;
      }

      setEmail(savedEmail);

      // If the link was already consumed in a previous session, but the user is still logged in, skip verification
      if (auth.currentUser && auth.currentUser.email === savedEmail) {
        setStep('set_password');
        return;
      }

      try {
        await completeSignInWithLink(savedEmail, url);
        setStep('set_password');
      } catch (err: any) {
        console.error("Link verification failed", err);
        setStep('error');
        setErrorMessage(err.message || 'Invitation link verification failed.');
      }
    };

    checkLink();
  }, [initialLoad, completeSignInWithLink]);

  const handleManualEmailSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedEmail = email.trim();
    if (!trimmedEmail) return;

    // Simple robust regex for email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(trimmedEmail)) {
      setErrorMessage('Please enter a valid email address.');
      return;
    }

    setLoading(true);
    setErrorMessage(null);
    try {
      if (auth.currentUser && auth.currentUser.email === trimmedEmail) {
        setStep('set_password');
        return;
      }
      await completeSignInWithLink(trimmedEmail, window.location.href);
      setStep('set_password');
    } catch (err: any) {
      setErrorMessage(err.message || 'Could not verify link with this email.');
    } finally {
      setLoading(false);
    }
  };

  const handleRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedName = displayName.trim();
    const trimmedPassword = password.trim();
    const trimmedConfirm = confirmPassword.trim();

    if (!trimmedName) {
      setErrorMessage('Please enter your full name.');
      return;
    }
    if (trimmedPassword.length < 8) {
      setErrorMessage('Password must be at least 8 characters long.');
      return;
    }
    if (trimmedPassword !== trimmedConfirm) {
      setErrorMessage('Passwords do not match.');
      return;
    }

    setLoading(true);
    setErrorMessage(null);
    try {
      const profile = await registerInvitedUser(trimmedName, trimmedPassword);
      setAssignedRole(profile.role);
      setStep('success');
      setTimeout(() => {
        window.location.href = '/';
      }, 2000);
    } catch (err: any) {
      console.error("Registration failed", err);
      setErrorMessage(err.message || 'Failed to complete registration.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-[radial-gradient(circle_at_50%_30%,rgba(34,78,40,0.6)_0%,rgba(10,23,13,0.98)_70%)]">
      <div className="w-full max-w-[480px]">
        <GlassCard glow className="p-9 text-center">
          {/* Logo & Header */}
          <div className="flex items-center justify-center gap-3.5 mb-7">
            <img
              src="/logo.png"
              alt="AgriVision Logo"
              className="w-[52px] h-[52px] object-contain rounded-xl drop-shadow-[0_0_10px_rgba(176,209,130,0.4)]"
            />
            <div className="text-left">
              <h1 className="text-2xl font-extrabold text-text-main tracking-tight leading-tight">AgriVision</h1>
              <p className="text-[11px] text-primary-light font-semibold">Staff Onboarding</p>
            </div>
          </div>

          {/* STEP 1: Verifying */}
          {step === 'verifying' && (
            <div className="py-5">
              <div className="w-5 h-5 rounded-full bg-primary-light shadow-glow animate-[pulseGlow_2s_infinite_ease-in-out] mx-auto mb-4" />
              <h2 className="text-lg font-bold text-white mb-2">Verifying Invitation</h2>
              <p className="text-[13px] text-text-muted">Validating your secure cryptographic access link...</p>
            </div>
          )}

          {/* STEP 2: Cross-Device Email Prompt */}
          {step === 'prompt_email' && (
            <div>
              <h2 className="text-lg font-extrabold text-white mb-1.5">Confirm Your Email</h2>
              <p className="text-xs text-text-muted mb-5 leading-relaxed">
                For your security, please confirm the email address this invitation was sent to.
              </p>

              {errorMessage && (
                <div className="flex items-center gap-2 p-3 bg-red-400/20 border border-red-400/40 rounded-lg text-red-300 text-xs mb-4 text-left">
                  <AlertCircle size={16} className="shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              <form onSubmit={handleManualEmailSubmit} className="flex flex-col gap-3.5 text-left">
                <div>
                  <label className="text-[11px] font-semibold text-text-muted block mb-1">Invited Email Address</label>
                  <input
                    type="email"
                    required
                    placeholder="agronomist@agrivision.ai"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                  />
                </div>
                <button type="submit" disabled={loading} className="btn-primary w-full justify-center mt-1.5">
                  <span>{loading ? 'Verifying...' : 'Verify Invitation'}</span>
                  <ArrowRight size={16} />
                </button>
              </form>
            </div>
          )}

          {/* STEP 3: Set Password & Profile */}
          {step === 'set_password' && (
            <div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary-medium/20 border border-primary-light/40 mb-4">
                <CheckCircle2 size={14} className="text-primary-main" />
                <span className="text-xs font-semibold text-primary-light">{email} Verified</span>
              </div>

              <h2 className="text-xl font-extrabold text-white mb-1.5">Create Your Account</h2>
              <p className="text-xs text-text-muted mb-5 leading-relaxed">
                Set up your password to access the Web Command Center and the iOS Mobile App.
              </p>

              {errorMessage && (
                <div className="flex items-center gap-2 p-3 bg-red-400/20 border border-red-400/40 rounded-lg text-red-300 text-xs mb-4 text-left">
                  <AlertCircle size={16} className="shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              <form onSubmit={handleRegisterSubmit} className="flex flex-col gap-3.5 text-left">
                <div>
                  <label className="flex items-center gap-1.5 text-[11px] font-semibold text-text-muted mb-1">
                    <User size={12} />
                    <span>Full Name</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Dr. Tariq Mahmood"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                  />
                </div>

                <div>
                  <label className="flex items-center gap-1.5 text-[11px] font-semibold text-text-muted mb-1">
                    <Lock size={12} />
                    <span>Password (min. 8 characters)</span>
                  </label>
                  <input
                    type="password"
                    required
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                  />
                </div>

                <div>
                  <label className="flex items-center gap-1.5 text-[11px] font-semibold text-text-muted mb-1">
                    <Lock size={12} />
                    <span>Confirm Password</span>
                  </label>
                  <input
                    type="password"
                    required
                    placeholder="••••••••"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="btn-primary w-full justify-center mt-2"
                >
                  <ShieldCheck size={16} />
                  <span>{loading ? 'Activating Account...' : 'Complete Registration'}</span>
                </button>
              </form>
            </div>
          )}

          {/* STEP 4: Success */}
          {step === 'success' && (
            <div className="py-4">
              <div className="w-14 h-14 rounded-full bg-primary-medium/20 flex items-center justify-center mx-auto mb-4 border border-primary-light/40">
                <CheckCircle2 size={32} className="text-primary-main" />
              </div>
              <h2 className="text-xl font-extrabold text-white mb-2">Registration Complete!</h2>
              <p className="text-[13px] text-text-muted mb-4">
                Your account has been activated with the role: <b className="text-primary-light capitalize">{assignedRole}</b>.
              </p>
              <p className="text-xs text-text-dim">
                Redirecting you to the Command Center...
              </p>
            </div>
          )}

          {/* STEP 5: Error */}
          {step === 'error' && (
            <div className="py-4">
              <div className="w-14 h-14 rounded-full bg-red-400/20 flex items-center justify-center mx-auto mb-4 border border-red-400/40">
                <AlertCircle size={30} className="text-red-400" />
              </div>
              <h2 className="text-lg font-extrabold text-white mb-2">Invitation Expired or Invalid</h2>
              <p className="text-[13px] text-text-muted mb-6 leading-relaxed">
                {errorMessage || 'This invitation link is invalid or has already been used. Please contact your Enterprise Administrator.'}
              </p>
              <button
                onClick={() => window.location.href = '/'}
                className="btn-secondary w-full justify-center"
              >
                Return to Login
              </button>
            </div>
          )}
        </GlassCard>
      </div>
    </div>
  );
};
