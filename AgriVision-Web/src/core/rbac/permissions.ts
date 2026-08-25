import type { UserRole } from './roles';

export type Permission =
  | 'gis:view'
  | 'gis:raster_export'
  | 'analytics:view'
  | 'analytics:export'
  | 'iot:view'
  | 'iot:provision'
  | 'iot:calibrate'
  | 'advisory:view'
  | 'advisory:approve'
  | 'advisory:override'
  | 'admin:all';

export const ROLE_PERMISSIONS: Record<UserRole, Permission[]> = {
  admin: [
    'gis:view',
    'gis:raster_export',
    'analytics:view',
    'analytics:export',
    'iot:view',
    'iot:provision',
    'iot:calibrate',
    'advisory:view',
    'advisory:approve',
    'advisory:override',
    'admin:all'
  ],
  agronomist: [
    'gis:view',
    'gis:raster_export',
    'analytics:view',
    'analytics:export',
    'iot:view',
    'iot:provision',
    'iot:calibrate',
    'advisory:view',
    'advisory:approve',
    'advisory:override'
  ],
  mobile_user: []
};

export function hasPermission(role: UserRole, permission: Permission): boolean {
  const permissions = ROLE_PERMISSIONS[role] || [];
  return permissions.includes('admin:all') || permissions.includes(permission);
}

export function canAccessTab(role: UserRole, tabId: string): boolean {
  switch (tabId) {
    case 'gis':
      return hasPermission(role, 'gis:view');
    case 'analytics':
      return hasPermission(role, 'analytics:view');
    case 'iot':
      return hasPermission(role, 'iot:view');
    case 'advisory':
      return hasPermission(role, 'advisory:view');
    case 'users':
      return hasPermission(role, 'admin:all');
    case 'settings':
      return hasPermission(role, 'gis:view');
    default:
      return false;
  }
}
