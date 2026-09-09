import React from 'react';
import { Layers, Activity, Droplet, Thermometer, ChevronRight, ChevronLeft, Satellite, CloudSun, AlertTriangle } from 'lucide-react';
import { GlassCard } from '../ui/GlassCard';
import { useActiveField, useActiveClient, useActiveDashboard } from '../../core/hooks/useFleet';
import { useUIStore } from '../../core/store/uiStore';
import { healthPresentation } from '../../core/utils/health';
import clsx from 'clsx';

/** Human-readable age, so a reviewer can judge whether a reading is worth acting on. */
function relativeAge(iso?: string): string | null {
  if (!iso) return null;
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms)) return null;
  const hours = Math.floor(ms / 3_600_000);
  if (hours < 1) return 'under an hour ago';
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export const GISInspectorDrawer: React.FC = () => {
  const activeField = useActiveField();
  const activeClient = useActiveClient();
  const { dashboard: dashboardData } = useActiveDashboard();
  const isInspectorOpen = useUIStore(s => s.isInspectorOpen);
  const setInspectorOpen = useUIStore(s => s.setInspectorOpen);

  const moisture = dashboardData?.sources.soil.data?.moisture;
  const soilTemp = dashboardData?.sources.soil.data?.surface_temp_c;
  const satellite = dashboardData?.sources.satellite;
  const ndviStats = satellite?.data?.statistics?.ndvi;
  const health = healthPresentation(activeField?.latest_health_score);
  const sceneAge = relativeAge(satellite?.data?.acquired_at);
  const cloud = satellite?.data?.cloud_percent;
  // A scene that is old or heavily clouded is weak evidence — say so rather than letting a
  // stale raster be read as today's field condition.
  const sceneIsWeak = (cloud !== undefined && cloud > 30)
    || (!!satellite?.data?.acquired_at && Date.now() - new Date(satellite.data.acquired_at).getTime() > 7 * 86_400_000);
  const pendingReviews = (dashboardData?.recommendations || []).filter(
    (r) => r.requires_expert_confirmation && r.expert_status === 'pending'
  ).length;

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
                  {activeField.crop_type} • {Number.isFinite(activeField.area_ha) ? `${activeField.area_ha.toFixed(2)} ha` : 'area unknown'}
                </span>
                {(activeField.owner_name || activeField.owner_email) && (
                  <span className="text-accent-cyan mt-1 text-xs" title={activeField.owner_email || undefined}>
                    Owner: {activeField.owner_name || activeField.owner_email}
                  </span>
                )}
              </div>
            </div>

            {/* Health verdict — the reason an agronomist opened this field at all. */}
            <GlassCard className="p-4 flex flex-col gap-2" style={{ borderColor: `${health.color}55` }}>
              <div className="flex items-center justify-between">
                <span className="text-xs text-text-muted">AI field health</span>
                <span className="text-xs font-bold px-2 py-0.5 rounded-full" style={{ background: `${health.color}22`, color: health.color }}>
                  {health.label}
                </span>
              </div>
              <div className="flex items-end gap-2">
                <span className="text-3xl font-extrabold" style={{ color: health.color }}>
                  {activeField.latest_health_score !== undefined && activeField.latest_health_score !== null
                    ? activeField.latest_health_score.toFixed(0)
                    : '--'}
                </span>
                {activeField.latest_health_score !== undefined && activeField.latest_health_score !== null && (
                  <span className="text-xs text-text-muted mb-1">/ 100</span>
                )}
              </div>
              {activeField.latest_health_rationale && (
                <p className="text-[11px] text-text-muted leading-relaxed">{activeField.latest_health_rationale}</p>
              )}
              {relativeAge(activeField.latest_health_updated_at) && (
                <p className="text-[10px] text-text-dim">Assessed {relativeAge(activeField.latest_health_updated_at)}</p>
              )}
              {pendingReviews > 0 && (
                <div className="flex items-center gap-1.5 text-[11px] text-accent-orange mt-1">
                  <AlertTriangle size={12} />
                  {pendingReviews} recommendation{pendingReviews > 1 ? 's' : ''} awaiting your review
                </div>
              )}
            </GlassCard>

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
               <div className="flex items-center gap-2 mb-3">
                 <Satellite size={14} className="text-accent-cyan" />
                 <h3 className="text-sm font-semibold text-text-main">Zonal Analysis</h3>
               </div>
               <div className="flex justify-between items-end border-b border-white/5 pb-2">
                 <span className="text-xs text-text-muted">Mean NDVI</span>
                 {/* No invented fallback: an unavailable statistic reads as unavailable. */}
                 <span className="text-accent-cyan font-bold font-mono">
                   {ndviStats?.mean !== undefined ? ndviStats.mean.toFixed(2) : '--'}
                 </span>
               </div>
               <div className="flex justify-between items-end pt-2 pb-2 border-b border-white/5">
                 <span className="text-xs text-text-muted">Std Dev</span>
                 <span className="text-white font-mono">
                   {ndviStats?.std !== undefined ? ndviStats.std.toFixed(4) : '--'}
                 </span>
               </div>

               {/* Scene provenance: NDVI is only as trustworthy as the image behind it. */}
               <div className="flex flex-col gap-1 pt-2.5">
                 <div className="flex justify-between items-center">
                   <span className="text-xs text-text-muted flex items-center gap-1">
                     <CloudSun size={12} /> Cloud cover
                   </span>
                   <span className="text-xs font-mono text-white">
                     {cloud !== undefined ? `${cloud.toFixed(0)}%` : '--'}
                   </span>
                 </div>
                 <div className="flex justify-between items-center">
                   <span className="text-xs text-text-muted">Scene captured</span>
                   <span className="text-xs font-mono text-white">{sceneAge ?? '--'}</span>
                 </div>
                 {sceneIsWeak && (
                   <p className="text-[10px] text-accent-orange leading-relaxed mt-1.5 flex items-start gap-1">
                     <AlertTriangle size={11} className="shrink-0 mt-0.5" />
                     Imagery is stale or heavily clouded — treat this NDVI as weak evidence.
                   </p>
                 )}
                 {!satellite?.data && (
                   <p className="text-[10px] text-text-dim mt-1">
                     {satellite?.message || 'No satellite scene available for this field yet.'}
                   </p>
                 )}
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
