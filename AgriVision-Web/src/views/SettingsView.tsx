import React, { useState, useEffect } from 'react';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { apiClient } from '../core/api/client';
import { Server, Globe, BrainCircuit, Save } from 'lucide-react';
import { useAuth } from '../core/auth/AuthContext';
import { useAISettings, useUpdateAISettings } from '../core/hooks/useAdvisoryHooks';
import type { AISettings } from '../core/types';

export const SettingsView: React.FC = () => {
  const apiUrl = apiClient.getBaseURL();
  const { user } = useAuth();
  
  const isAdmin = user?.role === 'admin';
  const { data: fetchedSettings } = useAISettings(isAdmin);
  const updateSettings = useUpdateAISettings();
  const [aiSettings, setAiSettings] = useState<AISettings | null>(null);

  useEffect(() => {
    if (fetchedSettings && !aiSettings) {
      setAiSettings(fetchedSettings);
    }
  }, [fetchedSettings, aiSettings]);

  const handleSaveAI = async () => {
    if (!aiSettings) return;
    try {
      await updateSettings.mutateAsync(aiSettings);
      alert('AI Configuration saved successfully! It is now active globally.');
    } catch (err) {
      alert('Failed to save AI configuration');
      console.error(err);
    }
  };

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

      {/* AI Admin Panel */}
      {user?.role === 'admin' && aiSettings && (
        <GlassCard className="p-6 border-accent-purple/30">
          <div className="flex items-center gap-2.5 mb-4 justify-between">
            <div className="flex items-center gap-2.5">
              <BrainCircuit size={18} className="text-accent-purple" />
              <h3 className="text-base font-bold text-text-main">Dynamic AI Configuration</h3>
            </div>
            <MetricBadge label="Admin Only" variant="warning" size="sm" />
          </div>

          <div className="flex flex-col gap-4">
            <div>
              <label className="text-xs font-semibold text-text-muted block mb-1.5">AI Provider Mode</label>
              <select
                className="w-full bg-black/40 border border-white/10 rounded-md px-3 py-2 text-sm text-white focus:outline-none focus:border-accent-purple"
                value={aiSettings.mode || 'free'}
                onChange={(e) => setAiSettings({ ...aiSettings, mode: e.target.value })}
              >
                <option value="free">AI Studio (Free Mode)</option>
                <option value="vertex">Vertex AI (Paid Enterprise)</option>
              </select>
            </div>

            <div>
              <label className="text-xs font-semibold text-text-muted block mb-1.5">Model Selection</label>
              <select
                className="w-full bg-black/40 border border-white/10 rounded-md px-3 py-2 text-sm text-white focus:outline-none focus:border-accent-purple"
                value={aiSettings.model || 'gemini-3.7-flash'}
                onChange={(e) => setAiSettings({ ...aiSettings, model: e.target.value })}
              >
                {aiSettings.mode === 'free' ? (
                  <>
                    <option value="gemini-3.7-flash">Gemini 3.7 Flash (Latest GA)</option>
                    <option value="gemini-3.6-flash">Gemini 3.6 Flash</option>
                    <option value="gemini-3.5-flash">Gemini 3.5 Flash</option>
                    <option value="gemini-3.5-flash-lite">Gemini 3.5 Flash-Lite</option>
                    <option value="gemini-2.0-flash">Gemini 2.0 Flash (Stable Fallback)</option>
                    <option value="gemini-1.5-flash">Gemini 1.5 Flash (Rock Solid)</option>
                    <option value="gemini-1.5-pro">Gemini 1.5 Pro (Legacy)</option>
                  </>
                ) : (
                  <>
                    <option value="gemini-3.7-flash">Gemini 3.7 Flash (Enterprise)</option>
                    <option value="gemini-3.6-flash">Gemini 3.6 Flash</option>
                    <option value="gemini-2.0-flash">Gemini 2.0 Flash (Stable Fallback)</option>
                    <option value="gemini-1.5-pro">Gemini 1.5 Pro (Rock Solid)</option>
                    <option value="gemini-1.5-flash">Gemini 1.5 Flash (Rock Solid)</option>
                  </>
                )}
              </select>
            </div>

            <div className="flex justify-end mt-2">
              <button
                onClick={handleSaveAI}
                disabled={updateSettings.isPending}
                className="btn-primary bg-accent-purple hover:bg-accent-purple/80 border-accent-purple/50 transition-colors"
              >
                <Save size={16} />
                {updateSettings.isPending ? 'Saving globally...' : 'Save Configuration'}
              </button>
            </div>
          </div>
        </GlassCard>
      )}
    </div>
  );
};
