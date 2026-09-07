import React from 'react';
import { useAuth } from '../../core/auth/AuthContext';
import { useFleetStore, selectClients, selectFilteredFields } from '../../core/store/fleetStore';
import { useIoTStore } from '../../core/store/iotStore';
import { useFields } from '../../core/hooks/useFarmQueries';
import { useUIStore } from '../../core/store/uiStore';
import { ROLE_METADATA } from '../../core/rbac/roles';
import { RefreshCw, MapPin, CloudSun, User, LogOut, Users, Menu } from 'lucide-react';

export const TopHeader: React.FC = () => {
  const fields = useFleetStore(selectFilteredFields);
  const activeField = useFleetStore(s => s.activeField);
  const setActiveField = useFleetStore(s => s.setActiveField);
  const clients = useFleetStore(selectClients);
  const activeClient = useFleetStore(s => s.activeClient);
  const setActiveClient = useFleetStore(s => s.setActiveClient);
  
  const dashboardData = useIoTStore(s => s.dashboardData);
  const setSidebarOpen = useUIStore(s => s.setSidebarOpen);
  
  const fieldsQuery = useFields();
  const refreshData = () => fieldsQuery.refetch();
  const loading = fieldsQuery.isFetching;

  const { user, signOut } = useAuth();
  
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';
  const weather = dashboardData?.sources.weather.data;
  const currentRoleMeta = user ? ROLE_METADATA[user.role] : null;

  return (
    <header className="min-h-[70px] border-b border-border-glass bg-bg-main/65 backdrop-blur-md px-4 md:px-7 py-3 md:py-0 flex flex-wrap items-center justify-between sticky top-0 z-30 gap-4">
      {/* Left: Hamburger (Mobile) + Client/Field Selector + Weather */}
      <div className="flex items-center gap-2 md:gap-3.5 flex-1 min-w-0">
        
        <button 
          className="btn-icon md:hidden"
          onClick={() => setSidebarOpen(true)}
        >
          <Menu size={20} />
        </button>

        {isStaff && (
          <div className="flex items-center gap-2 bg-[rgba(22,51,30,0.7)] border border-border-glass px-2 md:px-3.5 py-2 rounded-md min-w-0">
            <Users size={16} className="text-accent-cyan shrink-0" />
            <select
              value={activeClient?.id || ''}
              onChange={(e) => {
                const selected = clients.find((c) => c.id === e.target.value);
                setActiveClient(selected || null);
              }}
              className="bg-transparent border-none text-text-main font-heading font-bold text-xs md:text-sm outline-none cursor-pointer w-full text-ellipsis overflow-hidden whitespace-nowrap"
            >
              <option value="" className="bg-[#112616] text-white">All Farmers</option>
              {clients.map((c) => (
                <option key={c.id} value={c.id} className="bg-[#112616] text-white">
                  {c.email || 'Unknown User'}
                </option>
              ))}
            </select>
          </div>
        )}

        {(!isStaff || activeClient) && (
          <div className="flex items-center gap-2 bg-[rgba(22,51,30,0.7)] border border-border-glass px-2 md:px-3.5 py-2 rounded-md min-w-0">
            <MapPin size={16} className="text-accent-lime shrink-0" />
            <select
              value={activeField?.id || ''}
              onChange={(e) => {
                const val = e.target.value;
                if (!val) {
                  setActiveField(null);
                } else {
                  const selected = fields.find((f) => f.id === val);
                  if (selected) setActiveField(selected);
                }
              }}
              className="bg-transparent border-none text-text-main font-heading font-bold text-xs md:text-sm outline-none cursor-pointer w-full text-ellipsis overflow-hidden whitespace-nowrap"
            >
              <option value="" className="bg-[#112616] text-white">All Fields</option>
              {fields.map((f) => (
                <option key={f.id} value={f.id} className="bg-[#112616] text-white">
                  {f.name}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Live Weather Capsule */}
        {weather && (
          <div className="hidden lg:flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 border border-border-subtle text-xs text-text-muted shrink-0">
            <CloudSun size={15} className="text-accent-orange" />
            <span className="text-text-main font-semibold">
              {weather.current.temp_c ? `${Math.round(weather.current.temp_c)}°C` : '--'}
            </span>
            <span>•</span>
            <span className="truncate max-w-[120px]">{weather.current.description || 'Clear'}</span>
          </div>
        )}
      </div>

      {/* Right: Sync Button + User Profile + Sign Out */}
      <div className="flex items-center gap-2 md:gap-3.5 shrink-0">
        <button
          onClick={refreshData}
          disabled={loading}
          className="btn-secondary px-2 md:px-3.5 py-1.5 md:py-2 text-[13px]"
          title="Sync Satellite & AI"
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          <span className="hidden sm:inline">{loading ? 'Syncing...' : 'Sync Data'}</span>
        </button>

        {/* User Profile Tag */}
        {user && (
          <div className="hidden sm:flex items-center gap-2.5 py-1 pr-3 pl-1 bg-white/5 border border-border-subtle rounded-full">
            <div
              className="w-7 h-7 rounded-full flex items-center justify-center text-[#0a170d] font-extrabold text-xs"
              style={{ backgroundColor: currentRoleMeta?.badgeColor || 'var(--primary)' }}
            >
              <User size={14} />
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
          className="btn-danger p-1.5 md:p-2 text-xs"
          title="Sign Out"
        >
          <LogOut size={14} />
        </button>
      </div>
    </header>
  );
};
