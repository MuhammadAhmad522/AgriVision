import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  sendSignInLinkToEmail,
  isSignInWithEmailLink,
  signInWithEmailLink,
  updatePassword,
  updateProfile,
  type User as FirebaseUser
} from 'firebase/auth';
import { auth, googleProvider } from './firebase';
import type { UserProfile, UserRole } from '../rbac/roles';
import { HttpClient } from '../api/http';

interface AuthContextType {
  user: UserProfile | null;
  loading: boolean;
  initialLoad: boolean;
  authError: string | null;
  signInWithEmail: (email: string, pass: string) => Promise<void>;
  signInGoogle: () => Promise<void>;
  linkGoogleAccount: (email: string, pass: string, credential: any) => Promise<void>;
  signOut: () => Promise<void>;
  sendInviteLink: (email: string) => Promise<void>;
  completeSignInWithLink: (email: string, url: string) => Promise<FirebaseUser>;
  registerInvitedUser: (displayName: string, pass: string) => Promise<UserProfile>;
  refreshSession: () => Promise<UserProfile | null>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

/**
 * Calls POST /api/session/bootstrap to resolve the user's role from PostgreSQL.
 * This is the single source of truth for authorization — Firebase handles
 * authentication, and the backend database owns role assignment.
 */
const bootstrapSession = async (token: string): Promise<{ role: string; name?: string } | null> => {
  try {
    const http = new HttpClient();
    const res = await fetch(`${http.getBaseURL()}/api/session/bootstrap`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'X-Client': 'web'
      }
    });
    if (!res.ok) {
      let errMsg = `Backend synchronization failed (${res.status})`;
      try {
        const errData = await res.json();
        if (errData.error?.message) {
          errMsg = errData.error.message;
        }
      } catch {
        // Ignore JSON parse errors
      }
      throw new Error(errMsg);
    }
    const data = await res.json();
    return data.user;
  } catch (e) {
    console.error('Session bootstrap error:', e);
    throw e;
  }
};

/**
 * Builds a UserProfile from Firebase credentials + backend role resolution.
 */
const buildProfile = (fbUser: FirebaseUser, token: string, dbRole: string | undefined): UserProfile => ({
  uid: fbUser.uid,
  email: fbUser.email || '',
  displayName: fbUser.displayName || fbUser.email?.split('@')[0] || 'AgriVision User',
  photoURL: fbUser.photoURL || undefined,
  role: (dbRole || 'mobile_user') as UserRole,
  token
});

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState<boolean>(true); // Used for actions (signing in)
  const [initialLoad, setInitialLoad] = useState<boolean>(true); // Used for App.tsx global spinner
  const [authError, setAuthError] = useState<string | null>(null);

  const syncSession = async (fbUser: FirebaseUser): Promise<UserProfile> => {
    const token = await fbUser.getIdToken(true);
    const dbUser = await bootstrapSession(token);
    const profile = buildProfile(fbUser, token, dbUser?.role);
    setUser(profile);
    return profile;
  };

  /**
   * Firebase auth state listener. On every auth state change, we resolve the
   * user's role from the backend database — never from localStorage or hardcoded values.
   */
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (fbUser: FirebaseUser | null) => {
      if (fbUser) {
        try {
          await syncSession(fbUser);
        } catch (err: any) {
          console.error('Failed to initialize session from backend:', err);
          setAuthError(err.message || 'Authentication failed during backend synchronization.');
          // If backend sync fails, sign out from Firebase to prevent a broken half-authenticated state
          await firebaseSignOut(auth).catch(() => {}); 
          setUser(null);
        }
      } else {
        setUser(null);
      }
      setLoading(false);
      setInitialLoad(false);
    });

    return () => unsubscribe();
  }, []);

  /**
   * Sign in with email & password via Firebase Auth.
   * Role is resolved from the backend database after authentication.
   */
  const signInWithEmail = async (email: string, pass: string): Promise<void> => {
    setLoading(true);
    try {
      const creds = await signInWithEmailAndPassword(auth, email, pass);
      await syncSession(creds.user);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Sign in with Google OAuth popup via Firebase Auth.
   * Only registered staff (admin/agronomist) will pass the web portal gatekeeper.
   * Uninvited Google users will be assigned mobile_user and shown Access Denied.
   */
  const signInGoogle = async (): Promise<void> => {
    setLoading(true);
    try {
      const creds = await signInWithPopup(auth, googleProvider);
      await syncSession(creds.user);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Links a pending Google credential to an existing email/password account.
   */
  const linkGoogleAccount = async (email: string, pass: string, credential: any): Promise<void> => {
    setLoading(true);
    try {
      // 1. Sign in with the existing email and password
      const creds = await signInWithEmailAndPassword(auth, email, pass);
      // 2. Link the pending Google credential
      await import('firebase/auth').then(({ linkWithCredential }) => linkWithCredential(creds.user, credential));
      // 3. Bootstrap session
      await syncSession(creds.user);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Admin-initiated: sends a Firebase email link to an invited user's address.
   * The link redirects to /invite/accept for registration.
   */
  const sendInviteLink = async (email: string): Promise<void> => {
    const actionCodeSettings = {
      url: window.location.origin + '/invite/accept',
      handleCodeInApp: true
    };
    await sendSignInLinkToEmail(auth, email, actionCodeSettings);
  };

  /**
   * Invited user: verifies the email link token and authenticates via Firebase.
   * Returns the Firebase user for subsequent password setup.
   */
  const completeSignInWithLink = async (email: string, url: string): Promise<FirebaseUser> => {
    if (!isSignInWithEmailLink(auth, url)) {
      throw new Error('Invalid or expired sign-in link.');
    }
    const result = await signInWithEmailLink(auth, email, url);
    return result.user;
  };

  /**
   * Invited user: sets their display name and password during onboarding.
   * After Firebase credentials are updated, bootstraps the backend session
   * to activate their assigned role from the invitations table.
   */
  const registerInvitedUser = async (displayName: string, pass: string): Promise<UserProfile> => {
    const currentUser = auth.currentUser;
    if (!currentUser) {
      throw new Error('No authenticated session. Please use the invitation link first.');
    }
    await updateProfile(currentUser, { displayName });
    await updatePassword(currentUser, pass);
    return await syncSession(currentUser);
  };

  /**
   * Force-refreshes the session by re-fetching the token and re-bootstrapping.
   */
  const refreshSession = async (): Promise<UserProfile | null> => {
    const currentUser = auth.currentUser;
    if (!currentUser) return null;
    return await syncSession(currentUser);
  };

  /**
   * Signs out from Firebase and clears all local state.
   */
  const signOut = async (): Promise<void> => {
    try {
      await firebaseSignOut(auth);
    } catch (e) {
      console.warn('Firebase sign-out encountered a network issue, but local session will be cleared:', e);
    }
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        initialLoad,
        authError,
        signInWithEmail,
        signInGoogle,
        linkGoogleAccount,
        signOut,
        sendInviteLink,
        completeSignInWithLink,
        registerInvitedUser,
        refreshSession
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
