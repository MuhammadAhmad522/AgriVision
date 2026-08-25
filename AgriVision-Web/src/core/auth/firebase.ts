import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, browserLocalPersistence, setPersistence } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyA36wGrvCZLvKS7_l395Uq1ngWhivfIpaQ",
  authDomain: "agrivision-d6cd1.firebaseapp.com",
  projectId: "agrivision-d6cd1",
  storageBucket: "agrivision-d6cd1.firebasestorage.app",
  messagingSenderId: "332235164713",
  appId: "1:332235164713:web:cf308b43f9674dab0c2038"
};

export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();

// Avoid IndexedDB 'Database is closed/hidden' errors in incognito/strict browsers
setPersistence(auth, browserLocalPersistence).catch(console.error);
