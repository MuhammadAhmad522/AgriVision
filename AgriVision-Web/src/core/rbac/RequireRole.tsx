import React from 'react';
import { useAuth } from '../auth/AuthContext';
import { hasPermission, type Permission } from './permissions';
import { GlassCard } from '../../components/ui/GlassCard';
import { ShieldAlert } from 'lucide-react';

interface RequirePermissionProps {
  permission: Permission;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export const RequirePermission: React.FC<RequirePermissionProps> = ({
  permission,
  children,
  fallback
}) => {
  const { user } = useAuth();

  if (!user) return null;

  const allowed = hasPermission(user.role, permission);

  if (!allowed) {
    if (fallback) return <>{fallback}</>;

    return (
      <GlassCard glow style={{ textAlign: 'center', padding: '40px 20px', maxWidth: '500px', margin: '40px auto' }}>
        <div
          style={{
            width: '54px',
            height: '54px',
            borderRadius: '50%',
            background: 'rgba(239, 68, 68, 0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 16px',
            border: '1px solid rgba(239, 68, 68, 0.4)'
          }}
        >
          <ShieldAlert size={28} color="#f87171" />
        </div>
        <h3 style={{ fontSize: '18px', fontWeight: 800, color: '#fff', marginBottom: '8px' }}>
          Access Restricted
        </h3>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', lineHeight: 1.5 }}>
          Your current role (<b>{user.role}</b>) does not have permission <code>{permission}</code> to access this operation.
        </p>
      </GlassCard>
    );
  }

  return <>{children}</>;
};
