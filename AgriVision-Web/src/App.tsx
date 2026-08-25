import React from 'react';
import { AuthProvider, useAuth } from './core/auth/AuthContext';
import { FarmProvider, useFarm } from './core/context/FarmContext';
import { Sidebar } from './components/layout/Sidebar';
import { TopHeader } from './components/layout/TopHeader';
import { LoginView } from './views/LoginView';
import { GISMapView } from './views/GISMapView';
import { FleetAnalyticsView } from './views/FleetAnalyticsView';
import { IoTHardwareView } from './views/IoTHardwareView';
import { AIAdvisoryView } from './views/AIAdvisoryView';
import { SettingsView } from './views/SettingsView';
import { UsersView } from './views/UsersView';
import { InviteAcceptView } from './views/InviteAcceptView';
import { RequirePermission } from './core/rbac/RequireRole';
import { GlassCard } from './components/ui/GlassCard';

const AppContent: React.FC = () => {
  const { user, initialLoad, signOut } = useAuth();
  const { activeTab } = useFarm();

  if (initialLoad) {
    return <div className="min-h-screen bg-bg-main" />;
  }

  if (window.location.pathname === '/invite/accept') {
    return <InviteAcceptView />;
  }

  if (!user) {
    return <LoginView />;
  }

  if (user.role === 'mobile_user') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg-main p-6">
        <GlassCard className="max-w-[400px] w-full text-center p-10 border border-accent-red/20 bg-accent-red/5">
          <h2 className="text-accent-red text-xl font-bold mb-4">Access Denied</h2>
          <p className="text-text-muted text-sm leading-relaxed mb-6">
            The Web Portal is restricted to authorized personnel only. Please use the AgriVision iOS app.
          </p>
          <button 
            onClick={async () => {
              if (signOut) {
                await signOut();
              } else {
                window.location.href = '/';
              }
            }} 
            className="btn-secondary w-full justify-center"
          >
            Go Back
          </button>
        </GlassCard>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-bg-main text-text-main font-body">
      {/* Fixed Left Sidebar with RBAC filtered tabs */}
      <Sidebar />

      {/* Main Workspace Area */}
      <div className="flex-1 flex flex-col min-w-0">
        <TopHeader />

        <main className="flex-1 p-6 md:p-7 overflow-y-auto">
          {activeTab === 'gis' && (
            <RequirePermission permission="gis:view">
              <GISMapView />
            </RequirePermission>
          )}

          {activeTab === 'analytics' && (
            <RequirePermission permission="analytics:view">
              <FleetAnalyticsView />
            </RequirePermission>
          )}

          {activeTab === 'iot' && (
            <RequirePermission permission="iot:view">
              <IoTHardwareView />
            </RequirePermission>
          )}

          {activeTab === 'advisory' && (
            <RequirePermission permission="advisory:view">
              <AIAdvisoryView />
            </RequirePermission>
          )}

          {activeTab === 'users' && (
            <RequirePermission permission="admin:all">
              <UsersView />
            </RequirePermission>
          )}

          {activeTab === 'settings' && <SettingsView />}
        </main>
      </div>
    </div>
  );
};

export function App() {
  return (
    <AuthProvider>
      <FarmProvider>
        <AppContent />
      </FarmProvider>
    </AuthProvider>
  );
}

export default App;
