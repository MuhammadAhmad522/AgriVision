import React from 'react';
import { Layers, Activity, Droplet, Thermometer, ChevronRight, ChevronLeft } from 'lucide-react';
import { GlassCard } from '../ui/GlassCard';
import { useFleetStore } from '../../core/store/fleetStore';
import { useIoTStore } from '../../core/store/iotStore';
import { useUIStore } from '../../core/store/uiStore';
import clsx from 'clsx';

export const GISInspectorDrawer: React.FC = () => {
  const activeField = useFleetStore(s => s.activeField);
  const activeClient = useFleetStore(s => s.activeClient);
  const dashboardData = useIoTStore(s => s.dashboardData);
  const isInspectorOpen = useUIStore(s => s.isInspectorOpen);
  const setInspectorOpen = useUIStore(s => s.setInspectorOpen);

  const moisture = dashboardData?.sources.soil.data?.moisture;
  const soilTemp = dashboardData?.sources.soil.data?.surface_temp_c;
  const ndviStats = dashboardData?.sources.satellite.data?.statistics?.ndvi;

  return (
    <div 
      className={clsx(
        "absolute right-0 top-0 bottom-0 bg-[#0c1a11]/95 backdrop-blur-md border-l border-border-glass shadow-2xl transition-transform duration-300 z-20 pointer-events-auto w-[calc(100%-32px)] md:w-[340px]",
        isInspectorOpen ? "translate-x-0" : "translate-x-full"
      )}
    >
      {/* Toggle Button Tab */}
      <button
        onClick={() => setInspectorOpen(!isInspectorOpen)}
        className="absolute top-6 -left-8 w-8 h-12 bg-[#0c1a11]/95 backdrop-blur-md border-l border-y border-border-glass rounded-l-lg flex items-center justify-center text-text-muted hover:text-white transition-colors cursor-pointer"
        title={isInspectorOpen ? "Close Inspector" : "Open Inspector"}
      >
        {isInspectorOpen ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
      </button>

      <div className="p-5 h-full overflow-y-auto">
        {activeField ? (
          <div className="flex flex-col gap-5 animate-in slide-in-from-right duration-300">
            <div>
              <h2 className="text-xl font-heading font-bold text-white mb-1">{activeField.name}</h2>
              <div className="flex flex-col gap-1 text-sm text-text-muted">
                <span className="bg-white/10 px-2 py-0.5 rounded-full inline-block w-max text-xs">
                  {activeField.crop_type} • {activeField.area_ha} ha
                </span>
                {activeField.owner_email && (
                  <span className="text-accent-cyan mt-1 text-xs">Owner: {activeField.owner_email}</span>
                )}
              </div>
            </div>

            <GlassCard className="p-4 flex flex-col gap-3 border-accent-lime/20">
              <div className="flex items-center gap-2 text-text-main font-semibold border-b border-border-subtle pb-2">
                <Activity size={16} className="text-accent-lime" />
                Latest Telemetry
              </div>
              
              <div className="grid grid-cols-2 gap-3">
                <div className="flex flex-col">
                  <span className="text-xs text-text-muted mb-1 flex items-center gap-1">
                    <Droplet size={12}/> Moisture
                  </span>
                  <span className="text-lg font-bold text-white">
                    {moisture ? `${Math.round(moisture)}%` : '--'}
                  </span>
                </div>
                <div className="flex flex-col">
                  <span className="text-xs text-text-muted mb-1 flex items-center gap-1">
                    <Thermometer size={12}/> Soil Temp
                  </span>
                  <span className="text-lg font-bold text-white">
                    {soilTemp ? `${Math.round(soilTemp)}°C` : '--'}
                  </span>
                </div>
              </div>
            </GlassCard>

            <GlassCard className="p-4">
               <h3 className="text-sm font-semibold text-text-main mb-3">Zonal Analysis</h3>
               <div className="flex justify-between items-end border-b border-white/5 pb-2">
                 <span className="text-xs text-text-muted">Mean NDVI</span>
                 <span className="text-accent-orange font-bold font-mono">{ndviStats?.mean?.toFixed(2) || '0.74'}</span>
               </div>
               <div className="flex justify-between items-end pt-2">
                 <span className="text-xs text-text-muted">Std Dev</span>
                 <span className="text-white font-mono">{ndviStats?.std?.toFixed(4) || '0.0012'}</span>
               </div>
            </GlassCard>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center h-full text-center px-4 animate-in fade-in duration-500">
            <Layers size={48} className="text-border-subtle mb-4" />
            <h3 className="text-lg font-bold text-text-main mb-2">
              {activeClient ? `Viewing ${activeClient.email}` : 'Fleet View'}
            </h3>
            <p className="text-sm text-text-muted leading-relaxed">
              {activeClient 
                ? "Select a field on the map to view detailed telemetry, raster analysis, and AI advisories for this client." 
                : "Select a client from the top header to filter fields, or click any field polygon to inspect it."}
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
