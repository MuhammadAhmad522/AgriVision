export type UserRole = 'admin' | 'agronomist' | 'mobile_user';

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  photoURL?: string;
  role: UserRole;
  token?: string;
}

export const ROLE_METADATA: Record<UserRole, { label: string; description: string; badgeColor: string; icon: string }> = {
  admin: {
    label: 'Platform Admin',
    description: 'Full governance: user invitations, platform analytics, system settings, GIS & AI advisory.',
    badgeColor: '#c084fc',
    icon: 'ShieldAlert'
  },
  agronomist: {
    label: 'Lead Agronomist',
    description: 'Specialized in Sentinel-2 NDVI spectral raster analysis, IoT telemetry, and AI agronomic advisory.',
    badgeColor: '#9ad46c',
    icon: 'Microscope'
  },
  mobile_user: {
    label: 'Mobile App User',
    description: 'Public farm manager/farmer using the iOS Mobile App. No Web Portal access.',
    badgeColor: '#9ca3af',
    icon: 'User'
  }
};
