import React from 'react';
import { useFarm } from '../../core/context/FarmContext';
import { useAuth } from '../../core/auth/AuthContext';
import { canAccessTab } from '../../core/rbac/permissions';
import { ROLE_METADATA } from '../../core/rbac/roles';
import { Map, BarChart3, Radio, Sparkles, Settings, Layers, LogOut, User } from 'lucide-react';
import clsx from 'clsx';

export const Sidebar: React.FC = () => {
  const { activeTab, setActiveTab, fields } = useFarm();
  const { user, signOut } = useAuth();

  const allNavItems = [
    { id: 'gis', label: 'GIS Command Center', icon: Map, badge: 'Live GIS' },
    { id: 'analytics', label: 'Fleet Analytics', icon: BarChart3, badge: null },
    { id: 'iot', label: 'IoT Hardware Fleet', icon: Radio, badge: '3 Nodes' },
    { id: 'advisory', label: 'AI Agronomy Studio', icon: Sparkles, badge: 'Gemini' },
    { id: 'users', label: 'User Management', icon: User, badge: 'Admin' },
    { id: 'settings', label: 'Control Settings', icon: Settings, badge: null }
  ];

  // RBAC Filtered Navigation Items
  const navItems = user
    ? allNavItems.filter((item) => canAccessTab(user.role, item.id))
    : allNavItems;

  const currentRoleMeta = user ? ROLE_METADATA[user.role] : null;

  return (
    <aside className="w-[270px] min-h-screen bg-bg-main/85 backdrop-blur-xl border-r border-border-glass p-6 flex flex-col gap-5 sticky top-0 z-40">
      {/* Official AgriVision Brand Header */}
      <div className="flex items-center gap-3 px-2">
        <img
          src="/logo.png"
          alt="AgriVision Logo"
          className="w-10 h-10 object-contain rounded-xl drop-shadow-[0_0_10px_rgba(176,209,130,0.4)]"
        />
        <div>
          <h1 className="text-lg font-extrabold text-text-main tracking-tight leading-tight">AgriVision</h1>
          <p className="text-[11px] text-primary-light font-semibold leading-tight">Command Portal</p>
        </div>
      </div>

      {/* Quick Fleet Pill */}
      <div className="px-3.5 py-2.5 bg-white/5 border border-border-subtle rounded-md flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Layers size={15} className="text-primary-light" />
          <span className="text-xs text-text-muted">Active Fleet</span>
        </div>
        <span className="text-xs font-bold text-accent-lime">
          {fields.length} Zones
        </span>
      </div>

      {/* Navigation Links */}
      <nav className="flex flex-col gap-1.5 flex-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={clsx(
                "flex items-center justify-between px-3.5 py-3 rounded-md cursor-pointer transition-all duration-200 text-left group",
                isActive 
                  ? "bg-primary-medium/25 border border-border-glass-bright text-green-50 shadow-glow" 
                  : "bg-transparent border border-transparent text-text-muted hover:bg-white/5 hover:text-text-main"
              )}
            >
              <div className="flex items-center gap-3">
                <Icon 
                  size={18} 
                  className={clsx(
                    isActive ? 'text-accent-lime' : 'text-current group-hover:text-primary-light transition-colors'
                  )} 
                />
                <span className={clsx("text-[13px]", isActive ? "font-bold" : "font-medium")}>
                  {item.label}
                </span>
              </div>
              {item.badge && (
                <span
                  className={clsx(
                    "text-[10px] font-bold px-1.5 py-0.5 rounded-full transition-colors",
                    isActive 
                      ? "bg-primary-light text-bg-main" 
                      : "bg-white/10 text-text-muted group-hover:bg-white/15"
                  )}
                >
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Authenticated User Profile & RBAC Card */}
      {user && (
        <div className="p-3 bg-[rgba(22,51,30,0.7)] border border-border-glass rounded-md flex flex-col gap-2.5">
          <div className="flex items-center gap-2.5">
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center text-bg-main font-extrabold text-[13px]"
              style={{ background: currentRoleMeta?.badgeColor || 'var(--color-primary)' }}
            >
              <User size={18} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs font-bold text-white whitespace-nowrap overflow-hidden text-ellipsis">
                {user.displayName}
              </p>
              <p 
                className="text-[10px] font-semibold leading-tight" 
                style={{ color: currentRoleMeta?.badgeColor || 'var(--color-primary-light)' }}
              >
                {currentRoleMeta?.label || user.role}
              </p>
            </div>

            <button
              onClick={signOut}
              title="Sign Out"
              className="p-1.5 rounded-md bg-accent-red/15 border border-accent-red/30 text-accent-red hover:bg-accent-red/25 hover:text-red-400 transition-colors"
            >
              <LogOut size={14} />
            </button>
          </div>
        </div>
      )}
    </aside>
  );
};
