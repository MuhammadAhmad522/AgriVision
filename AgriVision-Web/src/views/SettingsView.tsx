import React, { useState, useEffect } from 'react';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { apiClient } from '../core/api/client';
import { Server, Globe, BrainCircuit, Save, Activity, CheckCircle2, XCircle, Loader2 } from 'lucide-react';
import { useAuth } from '../core/auth/AuthContext';
import { useAISettings, useUpdateAISettings, useCheckAIHealth } from '../core/hooks/useAdvisoryHooks';
import type { AISettings, AIHealth } from '../core/types';
import { useToast } from '../core/ui/toast';
import {
  ALLOWED_AI_MODELS,
  isAllowedAiMode,
  isAllowedAiModel,
  describeError,
} from '../core/utils/sanitize';

export const SettingsView: React.FC = () => {
  const apiUrl = apiClient.getBaseURL();
  const { user } = useAuth();

  const isAdmin = user?.role === 'admin';
  const { data: fetchedSettings, isError: settingsError, refetch: refetchSettings } = useAISettings(isAdmin);
  const updateSettings = useUpdateAISettings();
  const healthCheck = useCheckAIHealth();
  const toast = useToast();
  const [aiSettings, setAiSettings] = useState<AISettings | null>(null);
  const [health, setHealth] = useState<AIHealth | null>(null);
  const [statusMsg, setStatusMsg] = useState<{ kind: 'success' | 'error' | 'info'; text: string } | null>(null);

  useEffect(() => {
    if (fetchedSettings && !aiSettings) {
      setAiSettings(fetchedSettings);
    }
  }, [fetchedSettings, aiSettings]);

  /** Reject anything not on the client whitelist before it can reach the API. */
  const validateConfig = (cfg: AISettings): string | null => {
    if (!isAllowedAiMode(cfg.mode)) return `"${cfg.mode}" is not a valid provider mode.`;
    if (!isAllowedAiModel(cfg.model)) return `"${cfg.model}" is not a supported model.`;
    return null;
  };

  const runHealthCheck = async () => {
    setStatusMsg({ kind: 'info', text: 'Contacting the AI provider…' });
    try {
      const result = await healthCheck.mutateAsync();
      setHealth(result);
      if (result.ok) {
        setStatusMsg({ kind: 'success', text: `AI is working — ${result.detail}` });
        toast.success(`AI verified: ${result.mode} / ${result.model}${result.latency_ms != null ? ` (${result.latency_ms} ms)` : ''}`);
      } else {
        setStatusMsg({ kind: 'error', text: `AI call failed — ${result.detail}` });
        toast.error(`AI check failed: ${result.detail}`);
      }
      return result.ok;
    } catch (err) {
      setHealth(null);
      const msg = describeError(err, 'Could not reach the health endpoint.');
      setStatusMsg({ kind: 'error', text: msg });
      toast.fromError(err, 'Could not reach the health endpoint.');
      return false;
    }
  };

  const handleSaveAI = async () => {
    if (!aiSettings) return;
    const invalid = validateConfig(aiSettings);
    if (invalid) {
      setStatusMsg({ kind: 'error', text: invalid });
      toast.error(invalid);
      return;
    }
    const payload: AISettings = { mode: aiSettings.mode, model: aiSettings.model };
    setStatusMsg({ kind: 'info', text: 'Saving configuration…' });
    try {
      await updateSettings.mutateAsync(payload);
      toast.success('AI configuration saved. It is now active globally.');
      setStatusMsg({ kind: 'info', text: 'Saved. Verifying the AI actually responds…' });
      await runHealthCheck();
    } catch (err) {
      const msg = describeError(err, 'Failed to save AI configuration.');
      setStatusMsg({ kind: 'error', text: msg });
      toast.fromError(err, 'Failed to save AI configuration.');
    }
  };

  const busy = updateSettings.isPending || healthCheck.isPending;
  const configInvalid = aiSettings ? validateConfig(aiSettings) : null;

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
              <p className="text-[13px] font-bold text-text-main">
                Google Gemini{aiSettings?.model ? ` · ${aiSettings.model}` : ''}
              </p>
              <p className="text-[11px] text-text-muted mt-0.5">
                Multimodal Agronomic Advisory Reasoning Engine
                {aiSettings?.mode ? ` — ${aiSettings.mode === 'free' ? 'AI Studio (free)' : 'Vertex AI (paid)'} mode` : ''}
              </p>
            </div>
            {health
              ? <MetricBadge label={health.ok ? 'Verified' : 'Failing'} variant={health.ok ? 'success' : 'danger'} size="sm" />
              : <MetricBadge label="Not tested" variant="neutral" size="sm" />}
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

      {/* AI Admin Panel — load error */}
      {isAdmin && !aiSettings && settingsError && (
        <GlassCard className="p-6 border-red-400/30">
          <div className="flex items-center gap-2.5 mb-2">
            <XCircle size={18} className="text-red-400" />
            <h3 className="text-base font-bold text-text-main">Dynamic AI Configuration</h3>
          </div>
          <p className="text-[12px] text-text-muted mb-4">
            Could not load the current AI configuration from the server.
          </p>
          <button
            onClick={() => refetchSettings()}
            className="inline-flex items-center gap-2 rounded-md border border-white/15 bg-white/5 px-3 py-2 text-[13px] font-semibold text-text-main hover:bg-white/10 transition-colors"
          >
            <Loader2 size={16} /> Retry
          </button>
        </GlassCard>
      )}

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
                value={aiSettings.model}
                onChange={(e) => setAiSettings({ ...aiSettings, model: e.target.value })}
              >
                {!isAllowedAiModel(aiSettings.model) && (
                  <option value={aiSettings.model}>{aiSettings.model} (unsupported)</option>
                )}
                {ALLOWED_AI_MODELS.map((m) => (
                  <option key={m} value={m}>{m}</option>
                ))}
              </select>
            </div>

            {configInvalid && (
              <p className="text-[11px] text-red-300 -mt-1">{configInvalid}</p>
            )}

            {/* Live status */}
            {statusMsg && (
              <div
                className={
                  'flex items-start gap-2.5 rounded-md border px-3 py-2.5 text-[12px] ' +
                  (statusMsg.kind === 'success'
                    ? 'bg-primary-medium/15 border-primary-light/40 text-accent-lime'
                    : statusMsg.kind === 'error'
                    ? 'bg-red-400/10 border-red-400/40 text-red-300'
                    : 'bg-white/5 border-white/15 text-text-muted')
                }
              >
                {statusMsg.kind === 'success' ? (
                  <CheckCircle2 size={15} className="mt-0.5 shrink-0" />
                ) : statusMsg.kind === 'error' ? (
                  <XCircle size={15} className="mt-0.5 shrink-0" />
                ) : (
                  <Loader2 size={15} className="mt-0.5 shrink-0 animate-spin" />
                )}
                <span className="leading-snug">{statusMsg.text}</span>
              </div>
            )}

            {health && (
              <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-[11px] text-text-dim">
                <span>Resolved mode: <span className="text-text-muted">{health.mode}</span></span>
                <span>Model: <span className="text-text-muted">{health.model}</span></span>
                <span>Provider: <span className="text-text-muted">{health.provider}</span></span>
                <span>Knowledge: <span className="text-text-muted">{health.knowledge}</span></span>
                {health.latency_ms != null && (
                  <span>Latency: <span className="text-text-muted">{health.latency_ms} ms</span></span>
                )}
              </div>
            )}

            <div className="flex justify-between items-center mt-2">
              <button
                onClick={runHealthCheck}
                disabled={busy}
                className="inline-flex items-center gap-2 rounded-md border border-white/15 bg-white/5 px-3 py-2 text-[13px] font-semibold text-text-main hover:bg-white/10 transition-colors disabled:opacity-50"
              >
                {healthCheck.isPending ? <Loader2 size={16} className="animate-spin" /> : <Activity size={16} />}
                {healthCheck.isPending ? 'Testing…' : 'Test Connection'}
              </button>

              <button
                onClick={handleSaveAI}
                disabled={busy || !!configInvalid}
                className="btn-primary bg-accent-purple hover:bg-accent-purple/80 border-accent-purple/50 transition-colors disabled:opacity-50"
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
