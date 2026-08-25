import React from 'react';
import { useFarm } from '../../core/context/FarmContext';
import { useAuth } from '../../core/auth/AuthContext';
import { ROLE_METADATA } from '../../core/rbac/roles';
import { RefreshCw, MapPin, CloudSun, User, LogOut } from 'lucide-react';

export const TopHeader: React.FC = () => {
  const { fields, activeField, setActiveField, dashboardData, refreshData, loading } = useFarm();
  const { user, signOut } = useAuth();

  const weather = dashboardData?.sources.weather.data;
  const currentRoleMeta = user ? ROLE_METADATA[user.role] : null;

  return (
    <header className="h-[70px] border-b border-border-glass bg-bg-main/65 backdrop-blur-md px-7 flex items-center justify-between sticky top-0 z-30">
      {/* Left: Field Selector + Weather */}
      <div className="flex items-center gap-3.5">
        <div className="flex items-center gap-2 bg-[rgba(22,51,30,0.7)] border border-border-glass px-3.5 py-2 rounded-md">
          <MapPin size={16} className="text-accent-lime" />
          <select
            value={activeField?.id || ''}
            onChange={(e) => {
              const selected = fields.find((f) => f.id === e.target.value);
              if (selected) setActiveField(selected);
            }}
            className="bg-transparent border-none text-text-main font-heading font-bold text-sm outline-none cursor-pointer"
          >
            {fields.map((f) => (
              <option key={f.id} value={f.id} className="bg-[#112616] text-white">
                {f.name} ({f.crop_type} • {f.area_ha} ha)
              </option>
            ))}
          </select>
        </div>

        {/* Live Weather Capsule */}
        {weather && (
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 border border-border-subtle text-xs text-text-muted">
            <CloudSun size={15} className="text-accent-orange" />
            <span className="text-text-main font-semibold">
              {weather.current.temp_c ? `${Math.round(weather.current.temp_c)}°C` : '--'}
            </span>
            <span>•</span>
            <span>{weather.current.description || 'Clear'}</span>
          </div>
        )}
      </div>

      {/* Right: Sync Button + User Profile + Sign Out */}
      <div className="flex items-center gap-3.5">
        <button
          onClick={refreshData}
          disabled={loading}
          className="btn-secondary px-3.5 py-2 text-[13px] disabled:opacity-70 disabled:cursor-not-allowed"
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          <span>{loading ? 'Syncing...' : 'Sync Satellite & AI'}</span>
        </button>

        {/* User Profile Tag */}
        {user && (
          <div className="flex items-center gap-2.5 py-1.5 pr-3 pl-1.5 bg-white/5 border border-border-subtle rounded-full">
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center text-[#0a170d] font-extrabold text-xs"
              style={{ backgroundColor: currentRoleMeta?.badgeColor || 'var(--primary)' }}
            >
              <User size={16} />
            </div>
            <div>
              <p className="text-xs font-bold leading-none">
                {user.displayName.split(' ')[0]}
              </p>
              <p 
                className="text-[10px] leading-[1.2] mt-0.5"
                style={{ color: currentRoleMeta?.badgeColor || 'var(--primary-light)' }}
              >
                {currentRoleMeta?.label}
              </p>
            </div>
          </div>
        )}

        {/* Sign Out Button */}
        <button
          onClick={signOut}
          className="btn-secondary p-2 text-xs"
          title="Sign Out"
        >
          <LogOut size={14} />
        </button>
      </div>
    </header>
  );
};
