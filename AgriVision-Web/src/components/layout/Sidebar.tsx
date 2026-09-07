import React from 'react';
import { useAuth } from '../../core/auth/AuthContext';
import { useUIStore } from '../../core/store/uiStore';
import { useFleetStore } from '../../core/store/fleetStore';
import { canAccessTab } from '../../core/rbac/permissions';
import { ROLE_METADATA } from '../../core/rbac/roles';
import { Map, BarChart3, Radio, Sparkles, Settings, Layers, LogOut, User, PanelLeftClose, PanelLeftOpen } from 'lucide-react';
import clsx from 'clsx';

export const Sidebar: React.FC = () => {
  const activeTab = useUIStore(s => s.activeTab);
  const setActiveTab = useUIStore(s => s.setActiveTab);
  const fields = useFleetStore(s => s.allFields);
  
  const { user, signOut } = useAuth();
  const isSidebarOpen = useUIStore(s => s.isSidebarOpen);
  const setSidebarOpen = useUIStore(s => s.setSidebarOpen);

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
    <>
      {/* Mobile Overlay */}
      {isSidebarOpen && (
        <div 
          className="md:hidden fixed inset-0 bg-black/60 z-40 backdrop-blur-sm"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <aside className={clsx(
        "bg-bg-main/95 backdrop-blur-xl border-r border-border-glass flex flex-col gap-5 z-50 transition-all duration-300",
        // Responsive positioning
        "fixed inset-y-0 left-0 md:sticky md:top-0 h-screen",
        // Width and Translate
        isSidebarOpen 
          ? "w-[270px] p-6 translate-x-0" 
          : "w-[270px] md:w-[80px] p-6 md:p-4 -translate-x-full md:translate-x-0 items-center md:items-center"
      )}>
        {/* Toggle Button */}
        <div className={clsx("flex items-center", (isSidebarOpen || window.innerWidth < 768) ? "justify-end mb-[-10px]" : "justify-center w-full")}>
          <button
            onClick={() => setSidebarOpen(!isSidebarOpen)}
            className="btn-icon hidden md:flex"
            title={isSidebarOpen ? "Collapse Sidebar" : "Expand Sidebar"}
          >
            {isSidebarOpen ? <PanelLeftClose size={18} /> : <PanelLeftOpen size={18} />}
          </button>
          <button
            onClick={() => setSidebarOpen(false)}
            className="btn-icon md:hidden"
            title="Close Sidebar"
          >
            <PanelLeftClose size={18} />
          </button>
        </div>

      {/* Official AgriVision Brand Header */}
      <div className={clsx("flex items-center gap-3", isSidebarOpen ? "px-2" : "justify-center")}>
        <img
          src="/logo.png"
          alt="AgriVision Logo"
          className={clsx("object-contain rounded-xl drop-shadow-[0_0_10px_rgba(176,209,130,0.4)]", isSidebarOpen ? "w-10 h-10" : "w-10 h-10")}
        />
        {isSidebarOpen && (
          <div className="animate-in fade-in duration-300">
            <h1 className="text-lg font-extrabold text-text-main tracking-tight leading-tight whitespace-nowrap">AgriVision</h1>
            <p className="text-[11px] text-primary-light font-semibold leading-tight whitespace-nowrap">Command Portal</p>
          </div>
        )}
      </div>

      {/* Quick Fleet Pill */}
      {isSidebarOpen ? (
        <div className="px-3.5 py-2.5 bg-white/5 border border-border-subtle rounded-md flex items-center justify-between animate-in fade-in duration-300">
          <div className="flex items-center gap-2">
            <Layers size={15} className="text-primary-light" />
            <span className="text-xs text-text-muted whitespace-nowrap">Active Fleet</span>
          </div>
          <span className="text-xs font-bold text-accent-lime whitespace-nowrap">
            {fields.length} Zones
          </span>
        </div>
      ) : (
        <div className="w-full py-2 bg-white/5 border border-border-subtle rounded-md flex justify-center text-primary-light" title={`${fields.length} Active Zones`}>
          <Layers size={18} />
        </div>
      )}

      {/* Navigation Links */}
      <nav className="flex flex-col gap-1.5 flex-1 w-full">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              title={!isSidebarOpen ? item.label : undefined}
              className={clsx(
                "flex items-center rounded-md cursor-pointer transition-all duration-200 group",
                isSidebarOpen ? "justify-between px-3.5 py-3 text-left" : "justify-center p-3",
                isActive 
                  ? "bg-primary-medium/25 border border-border-glass-bright text-green-50 shadow-glow" 
                  : "bg-transparent border border-transparent text-text-muted hover:bg-white/5 hover:text-text-main"
              )}
            >
              <div className="flex items-center gap-3">
                <Icon 
                  size={isSidebarOpen ? 18 : 20} 
                  className={clsx(
                    isActive ? 'text-accent-lime' : 'text-current group-hover:text-primary-light transition-colors'
                  )} 
                />
                {isSidebarOpen && (
                  <span className={clsx("text-[13px] whitespace-nowrap", isActive ? "font-bold" : "font-medium")}>
                    {item.label}
                  </span>
                )}
              </div>
              {isSidebarOpen && item.badge && (
                <span
                  className={clsx(
                    "text-[10px] font-bold px-1.5 py-0.5 rounded-full transition-colors whitespace-nowrap",
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
        <div className={clsx("border border-border-glass rounded-md flex flex-col gap-2.5 overflow-hidden", isSidebarOpen ? "p-3 bg-[rgba(22,51,30,0.7)]" : "p-2 bg-transparent items-center")}>
          <div className="flex items-center justify-between gap-2.5">
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center text-bg-main font-extrabold text-[13px] shrink-0"
              style={{ background: currentRoleMeta?.badgeColor || 'var(--color-primary)' }}
              title={!isSidebarOpen ? user.displayName : undefined}
            >
              <User size={18} />
            </div>
            
            {isSidebarOpen && (
              <div className="flex-1 min-w-0">
                <p className="text-xs font-bold text-white whitespace-nowrap overflow-hidden text-ellipsis">
                  {user.displayName}
                </p>
                <p 
                  className="text-[10px] font-semibold leading-tight whitespace-nowrap" 
                  style={{ color: currentRoleMeta?.badgeColor || 'var(--color-primary-light)' }}
                >
                  {currentRoleMeta?.label || user.role}
                </p>
              </div>
            )}

            <button
              onClick={signOut}
              title="Sign Out"
              className={clsx("btn-danger px-2 py-1.5 shrink-0", !isSidebarOpen && "mt-2")}
            >
              <LogOut size={14} />
            </button>
          </div>
        </div>
      )}
    </aside>
    </>
  );
};
