import React, { useMemo, useState } from 'react';
import { useFleetFields, useVisibleFields, useActiveField, useActiveClient, useFleetSensors, useClients } from '../core/hooks/useFleet';
import { clientLabel } from '../core/store/fleetStore';
import {
  useSensorHealth, usePairSensor, useAssignSensor, useDetachSensor, useUnpairSensor, useVerifySensor
} from '../core/hooks/useSensorHooks';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import {
  Radio, Battery, Plus, Terminal, Loader2, AlertTriangle, Link2Off, Search,
  ChevronDown, ChevronUp, Trash2, Link, Unlink, CheckCircle2, XCircle, Activity, Signal
} from 'lucide-react';
import { useRealtimeTelemetry } from '../core/hooks/useRealtimeTelemetry';
import clsx from 'clsx';
import type { SensorDevice, Field } from '../core/types';

/** Mirrors the backend's SENSOR_OFFLINE_CUTOFF_MINUTES (60). */
const SENSOR_ONLINE_WINDOW_MS = 60 * 60 * 1000;

type StatusFilter = 'all' | 'online' | 'offline' | 'unassigned';

function sensorIsOnline(lastSeen?: string): boolean {
  if (!lastSeen) return false;
  const ms = Date.now() - new Date(lastSeen).getTime();
  return !Number.isNaN(ms) && ms < SENSOR_ONLINE_WINDOW_MS;
}

function lastSeenLabel(iso?: string | null): string {
  if (!iso) return 'Never';
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms)) return 'Unknown';
  const mins = Math.floor(ms / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function durationLabel(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds)) return '--';
  if (seconds < 90) return `${Math.round(seconds)}s`;
  if (seconds < 5400) return `${Math.round(seconds / 60)}m`;
  return `${(seconds / 3600).toFixed(1)}h`;
}

const METRIC_LABELS: Record<string, string> = {
  temperature: 'Temperature',
  moisture: 'Moisture',
  humidity: 'Humidity',
  ph: 'pH',
  ec: 'EC',
  npk_n: 'Nitrogen',
  npk_p: 'Phosphorus',
  npk_k: 'Potassium',
};

// ---------------------------------------------------------------------------

export const IoTHardwareView: React.FC = () => {
  const { fields: allFields } = useFleetFields();
  const { fields: visibleFields } = useVisibleFields();
  const activeField = useActiveField();
  const activeClient = useActiveClient();
  const { sensors, isLoading, isError, refetch } = useFleetSensors();

  const [showPairModal, setShowPairModal] = useState(false);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [expanded, setExpanded] = useState<string | null>(null);

  // Respect the farmer picked in the header, matching every other screen. Probes with no
  // owner and no field are always shown: an unclaimed probe is what staff come here for.
  const scopedSensors = useMemo(() => {
    if (!activeClient) return sensors;
    return sensors.filter((s) => s.owner_id === activeClient.id || (!s.owner_id && !s.field_id));
  }, [sensors, activeClient]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return scopedSensors.filter((s) => {
      if (term) {
        const online = sensorIsOnline(s.last_seen);
        const haystack = [
          s.device_id,
          s.name,
          s.sensor_type,
          s.field_name,
          s.field_id ? '' : 'unassigned',
          s.owner_email,
          s.owner_name,
          s.owner_id ? '' : 'unclaimed',
          online ? 'online' : 'offline',
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        if (!haystack.includes(term)) return false;
      }
      const online = sensorIsOnline(s.last_seen);
      if (statusFilter === 'online') return online;
      if (statusFilter === 'offline') return !online;
      if (statusFilter === 'unassigned') return !s.field_id;
      return true;
    });
  }, [scopedSensors, search, statusFilter]);

  const offlineCount = scopedSensors.filter((s) => !sensorIsOnline(s.last_seen)).length;
  const unassignedCount = scopedSensors.filter((s) => !s.field_id).length;
  const lowBattery = scopedSensors.filter(
    (s) => typeof s.battery_level === 'number' && s.battery_level < 20
  ).length;

  const targetFieldId = activeField?.id ?? visibleFields[0]?.id;
  const mqttPackets = useRealtimeTelemetry(targetFieldId, 10000);

  return (
    <div className="flex flex-col gap-6 pb-10">
      <div className="flex flex-col sm:flex-row sm:justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-[22px] font-extrabold text-text-main">IoT Hardware &amp; Sensor Fleet</h2>
          {/* The old subtitle advertised "Real-time RS485 & wireless sensor nodes". No
              RS485 code exists in the firmware — the nodes publish over MQTT only. */}
          <p className="text-[13px] text-text-muted mt-1">
            ESP32 probes publishing to the Mosquitto broker on :1883
            {activeClient ? ` · scoped to ${clientLabel(activeClient)}` : ' · all farmers'}
          </p>
        </div>

        <button onClick={() => setShowPairModal(true)} className="btn-primary flex items-center gap-2">
          <Plus size={16} />
          <span>Provision New Sensor Node</span>
        </button>
      </div>

      {/* Fleet summary */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <SummaryTile icon={Radio} tone="lime" value={scopedSensors.length} label="Paired probes" />
        <SummaryTile
          icon={AlertTriangle}
          tone={offlineCount > 0 ? 'red' : 'dim'}
          value={offlineCount}
          label="Not reporting (>1h)"
        />
        <SummaryTile
          icon={Link2Off}
          tone={unassignedCount > 0 ? 'orange' : 'dim'}
          value={unassignedCount}
          label="Not on a field"
        />
        <SummaryTile
          icon={Battery}
          tone={lowBattery > 0 ? 'orange' : 'dim'}
          value={lowBattery}
          label="Battery under 20%"
        />
      </div>

      {/* Search + status filters. A fleet page with no way to find one probe stops
          working the moment there is more than a screenful of hardware. */}
      <div className="flex flex-col md:flex-row gap-3 md:items-center">
        <div className="relative flex-1 min-w-0">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-dim" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by device ID, name, field or farmer…"
            className="w-full bg-bg-main border border-border-glass rounded-md pl-9 pr-3 py-2 text-sm text-text-main outline-none focus:border-accent-lime transition-colors"
          />
        </div>
        <div className="flex rounded-md overflow-hidden border border-border-glass shrink-0">
          {(['all', 'online', 'offline', 'unassigned'] as StatusFilter[]).map((f) => (
            <button
              key={f}
              onClick={() => setStatusFilter(f)}
              className={clsx(
                'px-3 py-2 text-[11px] font-semibold capitalize transition-colors',
                statusFilter === f
                  ? 'bg-primary-medium/40 text-accent-lime'
                  : 'text-text-muted hover:text-text-main hover:bg-white/5'
              )}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      {/* Fleet table */}
      <GlassCard className="p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left text-[13px]">
            <thead>
              <tr className="border-b border-border-glass text-text-muted">
                <th className="p-4 font-semibold">Device Node ID</th>
                <th className="p-4 font-semibold">Farmer</th>
                <th className="p-4 font-semibold">Assigned Field</th>
                <th className="p-4 font-semibold">Battery</th>
                <th className="p-4 font-semibold">Status</th>
                <th className="p-4 font-semibold">Last Telemetry</th>
                <th className="p-4 font-semibold text-right">Manage</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((sensor) => (
                <SensorRow
                  key={sensor.id}
                  sensor={sensor}
                  fields={allFields}
                  expanded={expanded === sensor.id}
                  onToggle={() => setExpanded((prev) => (prev === sensor.id ? null : sensor.id))}
                />
              ))}

              {filtered.length === 0 && (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-text-muted text-xs">
                    {isLoading ? 'Loading paired hardware…'
                      : isError ? (
                        <span className="text-accent-red">
                          Could not load the sensor fleet. This is a failed request, not an empty fleet.
                        </span>
                      ) : scopedSensors.length === 0
                        ? 'No hardware paired yet. Use "Provision New Sensor Node" to pair a probe.'
                        : 'No probes match this search or filter.'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>

      {/* Telemetry inspector. Labelled honestly: this polls the readings API every 10
          seconds and renders what arrived — the browser holds no MQTT subscription. */}
      <GlassCard className="p-5">
        <div className="flex flex-wrap justify-between items-center gap-2 mb-3.5">
          <div className="flex items-center gap-2">
            <Terminal size={18} className="text-accent-lime" />
            <h3 className="text-[15px] font-bold text-text-main">Recent Telemetry</h3>
            <MetricBadge label="Polled every 10s" variant="neutral" size="sm" />
          </div>
          <span className="text-[11px] text-primary-light font-mono">
            {activeField ? activeField.name : visibleFields[0]?.name || 'No field selected'}
          </span>
        </div>

        <div className="bg-black/45 border border-border-subtle rounded-md p-3.5 font-mono text-xs flex flex-col gap-2 h-40 overflow-y-auto">
          {mqttPackets.length === 0 ? (
            <span className="text-text-muted italic">
              {targetFieldId
                ? 'No readings in the last hour for this field.'
                : 'Select a field to inspect its telemetry.'}
            </span>
          ) : (
            mqttPackets.map((pkt, idx) => (
              <div key={idx} className="flex gap-3 text-emerald-200 leading-tight">
                <span className="text-text-dim shrink-0">[{pkt.time}]</span>
                <span className="text-accent-cyan shrink-0">{pkt.topic}</span>
                <span className="text-gray-200 break-all">{pkt.payload}</span>
              </div>
            ))
          )}
        </div>
      </GlassCard>

      {showPairModal && (
        <PairSensorModal onClose={() => { setShowPairModal(false); refetch(); }} />
      )}
    </div>
  );
};

// ---------------------------------------------------------------------------

const TONES = {
  lime: { icon: 'text-accent-lime', value: 'text-text-main', border: '' },
  red: { icon: 'text-accent-red', value: 'text-accent-red', border: 'border-accent-red/40' },
  orange: { icon: 'text-accent-orange', value: 'text-accent-orange', border: 'border-accent-orange/40' },
  dim: { icon: 'text-text-dim', value: 'text-text-main', border: '' },
} as const;

const SummaryTile: React.FC<{
  icon: React.ComponentType<{ size?: number; className?: string }>;
  tone: keyof typeof TONES;
  value: number;
  label: string;
}> = ({ icon: Icon, tone, value, label }) => {
  const t = TONES[tone];
  return (
    <GlassCard className={clsx('p-4 flex items-center gap-3', t.border)}>
      <Icon size={18} className={clsx('shrink-0', t.icon)} />
      <div>
        <div className={clsx('text-lg font-bold leading-tight', t.value)}>{value}</div>
        <div className="text-[10px] text-text-muted">{label}</div>
      </div>
    </GlassCard>
  );
};

const Stat: React.FC<{ label: string; value: string; tone?: 'warn' }> = ({ label, value, tone }) => (
  <div>
    <div className={clsx('text-sm font-bold leading-tight', tone === 'warn' ? 'text-accent-orange' : 'text-text-main')}>
      {value}
    </div>
    <div className="text-[10px] text-text-muted">{label}</div>
  </div>
);

// ---------------------------------------------------------------------------

const SensorRow: React.FC<{
  sensor: SensorDevice;
  fields: Field[];
  expanded: boolean;
  onToggle: () => void;
}> = ({ sensor, fields, expanded, onToggle }) => {
  const isOnline = sensorIsOnline(sensor.last_seen);
  const hasBattery = sensor.battery_level !== undefined && sensor.battery_level !== null;
  const { data: health, isLoading: healthLoading } = useSensorHealth(sensor.device_id, expanded);

  const assignMutation = useAssignSensor();
  const detachMutation = useDetachSensor();
  const unpairMutation = useUnpairSensor();

  const [assigningTo, setAssigningTo] = useState('');
  const [confirmUnpair, setConfirmUnpair] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // A probe can only join a field owned by the same farmer — the backend enforces it, so
  // the dropdown must not offer fields that would 409.
  const assignableFields = useMemo(
    () => fields.filter((f) => !sensor.owner_id || f.owner_id === sensor.owner_id),
    [fields, sensor.owner_id]
  );

  const run = async (fn: () => Promise<unknown>) => {
    setError(null);
    try { await fn(); } catch (e: any) { setError(e?.message || 'Action failed.'); }
  };

  return (
    <>
      <tr className="border-b border-white/5 transition-colors hover:bg-white/5">
        <td className="p-4 font-bold text-text-main">
          <button onClick={onToggle} className="flex items-center gap-2 hover:text-accent-lime transition-colors">
            <Radio size={16} className={isOnline ? 'text-accent-lime' : 'text-text-dim'} />
            <span>{sensor.name || sensor.device_id}</span>
            {expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
          </button>
          {sensor.name && <div className="text-[10px] text-text-dim font-normal mt-0.5 pl-6">{sensor.device_id}</div>}
        </td>
        <td className="p-4 text-text-muted text-xs">
          {sensor.owner_name || sensor.owner_email
            ? <span title={sensor.owner_email || undefined}>{sensor.owner_name || sensor.owner_email}</span>
            : <span className="italic">Unclaimed</span>}
        </td>
        <td className="p-4">
          {sensor.field_name
            ? <span className="font-semibold text-accent-lime">{sensor.field_name}</span>
            : <span className="text-accent-orange text-xs">Unassigned</span>}
        </td>
        <td className="p-4">
          {/* A probe that never reports battery shows "--", not 0% — which would read as
              a flat battery needing replacement. */}
          {hasBattery ? (
            <div className="flex items-center gap-1.5">
              <Battery size={15} className={(sensor.battery_level as number) > 20 ? 'text-accent-lime' : 'text-accent-red'} />
              <span className="font-semibold text-text-main">{sensor.battery_level}%</span>
            </div>
          ) : (
            <span className="text-text-dim">--</span>
          )}
        </td>
        <td className="p-4">
          <MetricBadge label={isOnline ? 'Online' : 'Offline'} variant={isOnline ? 'success' : 'danger'} size="sm" />
        </td>
        <td className="p-4 text-text-dim" title={sensor.last_seen ? new Date(sensor.last_seen).toLocaleString() : undefined}>
          {lastSeenLabel(sensor.last_seen)}
        </td>
        <td className="p-4 text-right">
          <button onClick={onToggle} className="text-[11px] text-primary-light hover:text-accent-lime font-semibold transition-colors">
            {expanded ? 'Close' : 'Manage'}
          </button>
        </td>
      </tr>

      {expanded && (
        <tr className="border-b border-white/5 bg-black/25">
          <td colSpan={7} className="p-5">
            <div className="grid grid-cols-1 lg:grid-cols-[1.3fr_1fr] gap-6">
              {/* Reporting health */}
              <div>
                <h4 className="text-xs font-bold text-text-main flex items-center gap-1.5 mb-3">
                  <Activity size={13} className="text-accent-cyan" /> Reporting health (last 24h)
                </h4>
                {healthLoading && <p className="text-[11px] text-text-muted">Loading…</p>}
                {!healthLoading && health && (
                  <>
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-3">
                      <Stat label="Readings" value={health.reading_count.toLocaleString()} />
                      <Stat label="Median interval" value={durationLabel(health.median_interval_seconds)} />
                      <Stat
                        label="Longest gap"
                        value={durationLabel(health.longest_gap_seconds)}
                        tone={(health.longest_gap_seconds ?? 0) > 3600 ? 'warn' : undefined}
                      />
                      <Stat label="Last reading" value={lastSeenLabel(health.last_reading_at)} />
                    </div>

                    <div className="mb-3">
                      <p className="text-[10px] text-text-muted mb-1.5">Metrics this probe actually publishes</p>
                      {Object.keys(health.reporting_metrics).length === 0 ? (
                        <p className="text-[11px] text-accent-orange italic">Nothing published in this window.</p>
                      ) : (
                        <div className="flex flex-wrap gap-1.5">
                          {Object.entries(health.reporting_metrics).map(([metric, count]) => (
                            <span
                              key={metric}
                              className="text-[10px] px-2 py-0.5 rounded-full bg-primary-medium/20 text-accent-lime border border-primary-light/30"
                              title={`${count} readings carried this metric`}
                            >
                              {METRIC_LABELS[metric] || metric}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>

                    {health.latest && (
                      <div className="flex flex-wrap gap-4">
                        {Object.entries(health.latest)
                          .filter(([, v]) => v !== null && v !== undefined)
                          .map(([metric, value]) => (
                            <div key={metric}>
                              <div className="text-sm font-bold text-text-main">{Number(value).toFixed(1)}</div>
                              <div className="text-[10px] text-text-muted">{METRIC_LABELS[metric] || metric}</div>
                            </div>
                          ))}
                      </div>
                    )}
                  </>
                )}
                {!healthLoading && !health && (
                  <p className="text-[11px] text-text-muted">No reporting history available.</p>
                )}
              </div>

              {/* Management actions */}
              <div className="flex flex-col gap-3">
                <h4 className="text-xs font-bold text-text-main flex items-center gap-1.5">
                  <Signal size={13} className="text-accent-lime" /> Field assignment
                </h4>

                {sensor.field_id ? (
                  <div className="flex flex-col gap-2">
                    <p className="text-[11px] text-text-muted">
                      Attached to <span className="text-accent-lime font-semibold">{sensor.field_name}</span>.
                    </p>
                    <button
                      onClick={() => run(() => detachMutation.mutateAsync({ fieldId: sensor.field_id!, deviceId: sensor.device_id }))}
                      disabled={detachMutation.isPending}
                      className="btn-secondary text-xs py-1.5 px-3 flex items-center gap-1.5 w-fit disabled:opacity-50"
                    >
                      {detachMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : <Unlink size={13} />}
                      Detach from field
                    </button>
                    <p className="text-[10px] text-text-dim leading-relaxed">
                      Detaching keeps every reading this probe has taken. Un-pairing below does not.
                    </p>
                  </div>
                ) : (
                  <div className="flex flex-col gap-2">
                    {assignableFields.length === 0 ? (
                      <p className="text-[11px] text-accent-orange leading-relaxed">
                        No field belongs to this probe's owner
                        {sensor.owner_name || sensor.owner_email ? ` (${sensor.owner_name || sensor.owner_email})` : ''}, so it cannot be assigned yet.
                      </p>
                    ) : (
                      <div className="flex gap-2 flex-wrap">
                        <select
                          value={assigningTo}
                          onChange={(e) => setAssigningTo(e.target.value)}
                          className="bg-bg-main border border-border-glass rounded px-2.5 py-1.5 text-xs text-text-main outline-none focus:border-accent-lime"
                        >
                          <option value="">Select a field…</option>
                          {assignableFields.map((f) => (
                            <option key={f.id} value={f.id} className="bg-[#112616]">{f.name}</option>
                          ))}
                        </select>
                        <button
                          onClick={() => run(async () => {
                            await assignMutation.mutateAsync({ fieldId: assigningTo, deviceId: sensor.device_id, name: sensor.name || undefined });
                            setAssigningTo('');
                          })}
                          disabled={!assigningTo || assignMutation.isPending}
                          className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5 disabled:opacity-40"
                        >
                          {assignMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : <Link size={13} />}
                          Assign
                        </button>
                      </div>
                    )}
                  </div>
                )}

                <div className="pt-3 mt-1 border-t border-border-subtle">
                  {confirmUnpair ? (
                    <div className="flex flex-col gap-2">
                      <p className="text-[11px] text-accent-red leading-relaxed">
                        Un-pairing deletes this probe's record and <strong>every reading it has ever
                        taken</strong>. This cannot be undone. To simply move it, detach instead.
                      </p>
                      <div className="flex gap-2">
                        <button
                          onClick={() => run(async () => {
                            await unpairMutation.mutateAsync(sensor.device_id);
                            setConfirmUnpair(false);
                          })}
                          disabled={unpairMutation.isPending}
                          className="btn-danger text-xs py-1.5 px-3 flex items-center gap-1.5 disabled:opacity-50"
                        >
                          {unpairMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : <Trash2 size={13} />}
                          Yes, delete permanently
                        </button>
                        <button onClick={() => setConfirmUnpair(false)} className="text-xs text-text-muted hover:text-text-main px-2">
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <button
                      onClick={() => setConfirmUnpair(true)}
                      className="text-[11px] text-accent-red/80 hover:text-accent-red flex items-center gap-1.5 transition-colors"
                    >
                      <Trash2 size={12} /> Un-pair and erase this probe
                    </button>
                  )}
                </div>

                {error && (
                  <p className="text-[11px] text-accent-red flex items-center gap-1">
                    <AlertTriangle size={11} /> {error}
                  </p>
                )}
              </div>
            </div>
          </td>
        </tr>
      )}
    </>
  );
};

// ---------------------------------------------------------------------------

const PairSensorModal: React.FC<{ onClose: () => void }> = ({ onClose }) => {
  const clients = useClients();
  const activeClient = useActiveClient();
  const verifyMutation = useVerifySensor();
  const pairMutation = usePairSensor();

  const [deviceId, setDeviceId] = useState('');
  const [ownerId, setOwnerId] = useState(activeClient?.id || '');
  const [verified, setVerified] = useState<{ ok: boolean; message: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleVerify = async () => {
    const id = deviceId.trim();
    if (!id) return;
    setError(null);
    setVerified(null);
    try {
      const res = await verifyMutation.mutateAsync(id);
      setVerified({ ok: res.is_verified, message: res.message });
    } catch (e: any) {
      setError(e?.message || 'Could not reach the device registry.');
    }
  };

  const handlePair = async () => {
    const id = deviceId.trim();
    if (!id) { setError('Enter a device identifier.'); return; }
    setError(null);
    try {
      const res = await pairMutation.mutateAsync({ deviceId: id, ownerId: ownerId || undefined });
      setSuccess(res.message || 'Sensor paired.');
      window.setTimeout(onClose, 1400);
    } catch (e: any) {
      setError(e?.message || 'Failed to pair hardware. Check the device and try again.');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/75 backdrop-blur-md flex items-center justify-center z-[100] p-4">
      <div className="w-full max-w-[460px] bg-brand-charcoal-green border border-border-glass-bright rounded-xl p-6 shadow-[0_20px_40px_rgba(0,0,0,0.6)]">
        <h3 className="text-lg font-extrabold text-text-main mb-1.5">Pair New Hardware Node</h3>
        <p className="text-xs text-text-muted mb-4 leading-relaxed">
          Enter the device identifier the probe publishes over MQTT. It must have sent a
          heartbeat within the last hour to be pairable.
        </p>

        <div className="flex flex-col gap-3.5">
          <div>
            <label className="text-[11px] font-semibold text-text-muted block mb-1">Device Identifier</label>
            <div className="flex gap-2">
              <input
                type="text"
                placeholder="e.g. ESP32_FIELD_NODE_1"
                value={deviceId}
                onChange={(e) => { setDeviceId(e.target.value); setVerified(null); setError(null); }}
                disabled={pairMutation.isPending}
                className="flex-1 px-3 py-2 rounded bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors disabled:opacity-50"
              />
              <button
                onClick={handleVerify}
                disabled={!deviceId.trim() || verifyMutation.isPending}
                className="btn-secondary text-xs px-3 disabled:opacity-40"
              >
                {verifyMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : 'Verify'}
              </button>
            </div>
          </div>

          {/* Pair to the farmer, not to the signed-in agronomist. Pairing always claimed
              the probe for the caller, and staff own no fields — so a probe provisioned
              from this portal could never be assigned to anything. */}
          <div>
            <label className="text-[11px] font-semibold text-text-muted block mb-1">Pair on behalf of</label>
            <select
              value={ownerId}
              onChange={(e) => setOwnerId(e.target.value)}
              className="w-full px-3 py-2 rounded bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light"
            >
              <option value="" className="bg-[#112616]">My own account (staff-held spare)</option>
              {clients.map((c) => (
                <option key={c.id} value={c.id} className="bg-[#112616]">{clientLabel(c)}</option>
              ))}
            </select>
            <p className="text-[10px] text-text-dim mt-1 leading-relaxed">
              A probe can only be attached to a field owned by the same account. Pair it to the
              farmer who will use it.
            </p>
          </div>

          {verified && (
            <div className={clsx(
              'p-2.5 rounded text-xs leading-relaxed flex items-start gap-1.5 border',
              verified.ok
                ? 'bg-emerald-900/30 border-emerald-500/40 text-emerald-300'
                : 'bg-amber-900/30 border-amber-500/40 text-amber-300'
            )}>
              {verified.ok ? <CheckCircle2 size={13} className="shrink-0 mt-0.5" /> : <XCircle size={13} className="shrink-0 mt-0.5" />}
              {verified.message}
            </div>
          )}

          {error && (
            <div className="p-2.5 bg-red-900/30 border border-red-500/40 rounded text-red-300 text-xs leading-relaxed">
              {error}
            </div>
          )}
          {success && (
            <div className="p-2.5 bg-emerald-900/30 border border-emerald-500/40 rounded text-emerald-300 text-xs leading-relaxed">
              {success}
            </div>
          )}

          <div className="flex justify-end gap-2.5 mt-1">
            <button onClick={onClose} disabled={pairMutation.isPending} className="btn-secondary px-5">
              Cancel
            </button>
            <button
              onClick={handlePair}
              disabled={pairMutation.isPending || !deviceId.trim()}
              className="btn-primary px-5 flex items-center gap-2 disabled:opacity-50"
            >
              {pairMutation.isPending ? <Loader2 size={14} className="animate-spin" /> : null}
              {pairMutation.isPending ? 'Pairing…' : 'Pair Device'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
