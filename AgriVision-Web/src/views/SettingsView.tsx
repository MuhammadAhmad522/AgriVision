import React from 'react';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { apiClient } from '../core/api/client';
import { Server, Globe } from 'lucide-react';

export const SettingsView: React.FC = () => {
  const apiUrl = apiClient.getBaseURL();

  return (
    <div className="flex flex-col gap-6 pb-10 max-w-3xl">
      <div>
        <h2 className="text-[22px] font-extrabold text-text-main">Control Portal Configuration</h2>
        <p className="text-[13px] text-text-muted mt-1">
          Manage backend endpoints, synchronization intervals, and GIS provider settings.
        </p>
      </div>

      {/* Backend Connection */}
      <GlassCard glow className="p-6">
        <div className="flex items-center gap-2.5 mb-4">
          <Server size={18} className="text-accent-lime" />
          <h3 className="text-base font-bold text-text-main">FastAPI Backend Connection</h3>
        </div>

        <div className="flex flex-col gap-3">
          <div>
            <label className="text-xs font-semibold text-text-muted block mb-1.5">Active Server URL</label>
            <div className="flex gap-2.5 items-center">
              <code className="px-3.5 py-2.5 rounded-md bg-black/35 border border-border-glass text-white font-mono text-[13px] outline-none">
                {apiUrl}
              </code>
              <MetricBadge label="Connected" variant="success" size="sm" />
            </div>
          </div>
          <p className="text-[11px] text-text-dim">
            The API endpoint is securely configured via environment variables (<code className="text-primary-light/80 bg-white/5 px-1 py-0.5 rounded">VITE_API_URL</code>) and cannot be modified at runtime.
          </p>
        </div>
      </GlassCard>

      {/* Integration Providers Info */}
      <GlassCard className="p-6">
        <div className="flex items-center gap-2.5 mb-4">
          <Globe size={18} className="text-accent-cyan" />
          <h3 className="text-base font-bold text-text-main">Connected External Services</h3>
        </div>

        <div className="flex flex-col gap-3">
          <div className="flex justify-between items-center p-3 bg-black/20 rounded-md border border-white/5 hover:bg-black/30 transition-colors">
            <div>
              <p className="text-[13px] font-bold text-text-main">AgroMonitoring / Sentinel-2 Satellite</p>
              <p className="text-[11px] text-text-muted mt-0.5">Polygons, NDVI, EVI, Radar Soil & Thermal</p>
            </div>
            <MetricBadge label="Connected" variant="success" size="sm" />
          </div>

          <div className="flex justify-between items-center p-3 bg-black/20 rounded-md border border-white/5 hover:bg-black/30 transition-colors">
            <div>
              <p className="text-[13px] font-bold text-text-main">Google Gemini 3.7 Flash</p>
              <p className="text-[11px] text-text-muted mt-0.5">Multimodal Agronomic Advisory Reasoning Engine</p>
            </div>
            <MetricBadge label="Active" variant="success" size="sm" />
          </div>

          <div className="flex justify-between items-center p-3 bg-black/20 rounded-md border border-white/5 hover:bg-black/30 transition-colors">
            <div>
              <p className="text-[13px] font-bold text-text-main">Eclipse Mosquitto MQTT</p>
              <p className="text-[11px] text-text-muted mt-0.5">Telemetry Broker (:1883) for RS485 Field Probes</p>
            </div>
            <MetricBadge label="Broker Online" variant="info" size="sm" />
          </div>
        </div>
      </GlassCard>
    </div>
  );
};
