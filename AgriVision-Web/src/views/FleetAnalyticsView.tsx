import React, { useMemo, useState } from 'react';
import { useFleetStore, clientLabel } from '../core/store/fleetStore';
import { useVisibleFields, useActiveField, useActiveClient, useFleetSensors, useActiveDashboard } from '../core/hooks/useFleet';
import { healthPresentation, fieldsNeedingAttention, healthBand, HEALTH_LEGEND } from '../core/utils/health';
import { useAnalyticsData, RANGE_OPTIONS, ANALYTICS_RANGES, type AnalyticsRange, type TelemetryPoint } from '../core/hooks/useAnalyticsData';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { ChartState } from '../components/ui/ChartState';
import {
  Area,
  BarChart,
  Bar,
  ComposedChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts';
import {
  Sprout, FlaskConical, Thermometer, CloudRain, ArrowUpRight,
  AlertTriangle, Download, Radio, RefreshCw, Database, ArrowLeft
} from 'lucide-react';
import clsx from 'clsx';
import { exportService, EXPORT_KINDS, type ExportKind } from '../core/services/ExportService';

/** Mirrors the backend's SENSOR_OFFLINE_CUTOFF_MINUTES (60) rather than an arbitrary
 * client-side guess, so "online" means the same thing here as it does server-side. */
const SENSOR_ONLINE_WINDOW_MS = 60 * 60 * 1000;
const HECTARES_TO_ACRES = 2.471;
/** Stable empty array so the chart-domain memos don't recompute on every render while
 *  telemetry is still loading. */
const NO_POINTS: TelemetryPoint[] = [];

const CHART_TOOLTIP = {
  background: '#112616',
  borderColor: '#568c48',
  borderRadius: '8px',
  color: '#fff',
  fontSize: '12px',
} as const;

function isOnline(lastSeen?: string): boolean {
  if (!lastSeen) return false;
  const ms = Date.now() - new Date(lastSeen).getTime();
  return !Number.isNaN(ms) && ms < SENSOR_ONLINE_WINDOW_MS;
}

function relativeTime(ms: number | null): string {
  if (ms === null) return '--';
  const delta = Date.now() - ms;
  if (delta < 60_000) return 'just now';
  const mins = Math.floor(delta / 60_000);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

/** Pads a series domain so a flat-ish line is not squashed against the axis, and so real
 * readings outside a hardcoded band are never clipped out of view (the old charts pinned
 * moisture to [10,60] and temperature to [10,40] regardless of what the probe reported). */
function paddedDomain(values: number[]): [number, number] | undefined {
  const finite = values.filter((v) => Number.isFinite(v));
  if (finite.length === 0) return undefined;
  const min = Math.min(...finite);
  const max = Math.max(...finite);
  const pad = Math.max((max - min) * 0.15, 1);
  return [Number((min - pad).toFixed(1)), Number((max + pad).toFixed(1))];
}

// ---------------------------------------------------------------------------
// Fleet view (no field selected)
// ---------------------------------------------------------------------------

const FleetTriage: React.FC = () => {
  const { fields, isLoading, isError, isFetching, refetch, dataUpdatedAt } = useVisibleFields();
  const { sensors } = useFleetSensors();
  const activeClient = useActiveClient();
  const setActiveField = useFleetStore((s) => s.setActiveField);

  const stats = useMemo(() => {
    const scored = fields.filter(
      (f) => f.latest_health_score !== undefined && f.latest_health_score !== null
    );
    const meanHealth = scored.length > 0
      ? scored.reduce((acc, f) => acc + (f.latest_health_score as number), 0) / scored.length
      : null;

    // area_ha can be null on a field digitised without a boundary; a bare reduce turned
    // one such field into NaN acres for the entire estate.
    const totalAcres = fields.reduce(
      (acc, f) => acc + (Number.isFinite(f.area_ha) ? f.area_ha * HECTARES_TO_ACRES : 0),
      0
    );

    const visibleIds = new Set(fields.map((f) => f.id));
    const fleetSensors = sensors.filter((s) => s.field_id && visibleIds.has(s.field_id));

    // Distribution across the shared health bands — the fleet's shape in one row.
    const distribution = HEALTH_LEGEND.map((presentation) => ({
      ...presentation,
      count: fields.filter((f) => healthBand(f.latest_health_score) === presentation.band).length,
    }));

    // Health by crop: an agronomist advising several farmers wants to know whether a
    // problem is one field or the whole cotton block.
    const cropMap = new Map<string, { crop: string; count: number; scores: number[]; acres: number }>();
    for (const f of fields) {
      const crop = f.crop_type || 'Unspecified';
      let entry = cropMap.get(crop);
      if (!entry) {
        entry = { crop, count: 0, scores: [], acres: 0 };
        cropMap.set(crop, entry);
      }
      entry.count += 1;
      if (Number.isFinite(f.area_ha)) entry.acres += f.area_ha * HECTARES_TO_ACRES;
      if (f.latest_health_score !== undefined && f.latest_health_score !== null) {
        entry.scores.push(f.latest_health_score);
      }
    }
    const byCrop = Array.from(cropMap.values())
      .map((e) => ({
        crop: e.crop,
        count: e.count,
        acres: e.acres,
        meanScore: e.scores.length > 0 ? e.scores.reduce((a, b) => a + b, 0) / e.scores.length : null,
        scoredCount: e.scores.length,
      }))
      .sort((a, b) => {
        // Worst-scored crops first; crops with no assessment sink to the bottom.
        const sa = a.meanScore ?? Number.POSITIVE_INFINITY;
        const sb = b.meanScore ?? Number.POSITIVE_INFINITY;
        return sa - sb;
      });

    return {
      scoredCount: scored.length,
      meanHealth,
      totalAcres,
      attention: fieldsNeedingAttention(fields),
      totalSensors: fleetSensors.length,
      onlineSensors: fleetSensors.filter((s) => isOnline(s.last_seen)).length,
      unassessed: fields.length - scored.length,
      distribution,
      byCrop,
    };
  }, [fields, sensors]);

  const sortedFields = useMemo(
    () =>
      [...fields].sort((a, b) => {
        // Worst-scored first; unassessed fields sink to the bottom rather than being
        // treated as perfect (they previously defaulted to 100, ranking unknown as best).
        const scoreA = a.latest_health_score ?? Number.POSITIVE_INFINITY;
        const scoreB = b.latest_health_score ?? Number.POSITIVE_INFINITY;
        return scoreA - scoreB;
      }),
    [fields]
  );

  const meanPresentation = healthPresentation(stats.meanHealth);

  return (
    <div className="flex flex-col gap-6 pb-10 animate-in fade-in">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-text-main">Fleet Risk Triage</h2>
          <p className="text-sm text-text-muted mt-1">
            {activeClient ? `${clientLabel(activeClient)} · ` : 'All farmers · '}
            {fields.length} field{fields.length === 1 ? '' : 's'} ranked by AI health score, worst first.
          </p>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          className="btn-secondary text-xs py-1.5 px-3 flex items-center gap-1.5 disabled:opacity-50"
        >
          <RefreshCw size={13} className={isFetching ? 'animate-spin' : ''} />
          {isFetching ? 'Refreshing…' : `Updated ${relativeTime(dataUpdatedAt || null)}`}
        </button>
      </div>

      {/* Fleet KPIs. These belong on the fleet view — they were previously rendered only
          after a single field was selected, where they described the wrong scope. */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Total Acreage</span>
            <Sprout size={18} className="text-accent-lime" />
          </div>
          <h3 className="text-[28px] font-extrabold text-text-main leading-tight mt-3">
            {stats.totalAcres.toFixed(1)} <span className="text-sm font-medium">Acres</span>
          </h3>
          <p className="text-[11px] text-primary-light mt-1">
            Across {fields.length} field{fields.length === 1 ? '' : 's'}
          </p>
        </GlassCard>

        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Mean Field Health</span>
            <ArrowUpRight size={18} className="text-primary-light" />
          </div>
          <h3 className="text-[28px] font-extrabold leading-tight mt-3" style={{ color: meanPresentation.color }}>
            {stats.meanHealth !== null ? stats.meanHealth.toFixed(0) : '--'}
            {stats.meanHealth !== null && <span className="text-sm font-medium"> / 100</span>}
          </h3>
          <p className="text-[11px] text-text-muted mt-1">
            {stats.scoredCount > 0
              ? `${stats.scoredCount} of ${fields.length} assessed`
              : 'No AI assessment yet'}
          </p>
        </GlassCard>

        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Telemetry Probes</span>
            <Radio size={18} className="text-accent-cyan" />
          </div>
          <h3 className="text-[28px] font-extrabold text-text-main leading-tight mt-3">
            {stats.totalSensors > 0 ? `${stats.onlineSensors}/${stats.totalSensors}` : '--'}
            {stats.totalSensors > 0 && <span className="text-sm font-medium"> Online</span>}
          </h3>
          <p className="text-[11px] text-accent-cyan mt-1">
            {stats.totalSensors > 0
              ? `${Math.round((stats.onlineSensors / stats.totalSensors) * 100)}% reporting within the hour`
              : 'No probes on these fields'}
          </p>
        </GlassCard>

        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Needs Attention</span>
            <MetricBadge
              label={stats.attention.length > 0 ? 'Action required' : 'Clear'}
              variant={stats.attention.length > 0 ? 'danger' : 'success'}
            />
          </div>
          <h3 className={clsx(
            'text-[28px] font-extrabold leading-tight mt-3',
            stats.attention.length > 0 ? 'text-accent-red' : 'text-accent-lime'
          )}>
            {stats.attention.length} <span className="text-sm font-medium">Field{stats.attention.length === 1 ? '' : 's'}</span>
          </h3>
          <p className="text-[11px] text-text-muted mt-1">
            {stats.attention.length > 0
              ? `Worst: ${stats.attention[0].name}`
              : 'No fields below the at-risk threshold'}
          </p>
        </GlassCard>
      </div>

      {/* Health distribution + crop breakdown */}
      <div className="grid grid-cols-1 lg:grid-cols-[1fr_1.1fr] gap-5">
        <GlassCard className="p-5">
          <h3 className="text-base font-bold text-text-main mb-1">Health Distribution</h3>
          <p className="text-xs text-text-muted mb-4">How the fleet splits across the shared health bands.</p>

          {fields.length === 0 ? (
            <p className="text-xs text-text-muted italic py-6 text-center">No fields to summarise.</p>
          ) : (
            <>
              <div className="flex w-full h-3 rounded-full overflow-hidden gap-[2px] mb-4">
                {stats.distribution.filter((d) => d.count > 0).map((d) => (
                  <div
                    key={d.band}
                    style={{ background: d.color, flexGrow: d.count }}
                    title={`${d.label}: ${d.count}`}
                  />
                ))}
              </div>
              <div className="flex flex-col gap-2">
                {stats.distribution.map((d) => (
                  <div key={d.band} className="flex items-center justify-between text-xs">
                    <span className="flex items-center gap-2 text-text-muted">
                      <span className="w-2.5 h-2.5 rounded-full" style={{ background: d.color }} />
                      {d.label}
                    </span>
                    <span className="font-bold text-text-main">{d.count}</span>
                  </div>
                ))}
              </div>
            </>
          )}
        </GlassCard>

        <GlassCard className="p-5">
          <h3 className="text-base font-bold text-text-main mb-1">Health by Crop</h3>
          <p className="text-xs text-text-muted mb-4">
            Whether a problem is one field or the whole block. Worst mean score first.
          </p>
          {stats.byCrop.length === 0 ? (
            <p className="text-xs text-text-muted italic py-6 text-center">No fields to summarise.</p>
          ) : (
            <div className="flex flex-col gap-2.5">
              {stats.byCrop.map((c) => {
                const presentation = healthPresentation(c.meanScore);
                return (
                  <div key={c.crop} className="flex items-center gap-3 text-xs">
                    <span className="capitalize text-text-main font-medium w-28 shrink-0 truncate" title={c.crop}>
                      {c.crop}
                    </span>
                    <span className="text-text-dim w-24 shrink-0">
                      {c.count} field{c.count === 1 ? '' : 's'} · {c.acres.toFixed(0)}ac
                    </span>
                    <div className="flex-1 h-2 bg-black/40 rounded-full overflow-hidden">
                      {c.meanScore !== null && (
                        <div
                          className="h-full rounded-full"
                          style={{ width: `${c.meanScore}%`, background: presentation.color }}
                        />
                      )}
                    </div>
                    <span className="font-bold w-16 text-right shrink-0" style={{ color: presentation.color }}>
                      {c.meanScore !== null ? c.meanScore.toFixed(0) : 'n/a'}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </GlassCard>
      </div>

      <GlassCard className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-text-main">
            <thead className="bg-[#112616] text-text-muted text-xs uppercase border-b border-border-glass">
              <tr>
                <th className="px-6 py-4 font-semibold">Field Name</th>
                <th className="px-6 py-4 font-semibold">Crop</th>
                <th className="px-6 py-4 font-semibold">Overall Health</th>
                <th className="px-6 py-4 font-semibold hidden md:table-cell">AI Rationale</th>
                <th className="px-6 py-4 font-semibold text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border-glass">
              {sortedFields.map((field) => {
                const score = field.latest_health_score;
                const hasScore = score !== undefined && score !== null;
                const presentation = healthPresentation(score);

                return (
                  <tr
                    key={field.id}
                    className="hover:bg-[#1a3a23]/50 transition-colors cursor-pointer group"
                    onClick={() => setActiveField(field)}
                  >
                    <td className="px-6 py-4 font-medium flex items-center gap-3">
                      <div className="w-2 h-2 rounded-full shrink-0" style={{ background: presentation.color }} />
                      {field.name}
                    </td>
                    <td className="px-6 py-4 text-text-muted capitalize">{field.crop_type}</td>
                    <td className="px-6 py-4">
                      {hasScore ? (
                        <div className="flex items-center gap-3">
                          <div className="w-24 h-2 bg-black/40 rounded-full overflow-hidden">
                            <div
                              className="h-full rounded-full"
                              style={{ width: `${score}%`, background: presentation.color }}
                            />
                          </div>
                          <span className="font-bold" style={{ color: presentation.color }}>
                            {(score as number).toFixed(1)}
                          </span>
                        </div>
                      ) : (
                        // Not scored yet is its own state — never rendered as a full bar.
                        <span className="text-xs text-text-muted italic">Awaiting AI assessment</span>
                      )}
                    </td>
                    <td
                      className="px-6 py-4 text-xs text-text-muted hidden md:table-cell max-w-[250px] truncate"
                      title={field.latest_health_rationale || undefined}
                    >
                      {field.latest_health_rationale || <span className="italic opacity-60">No rationale recorded</span>}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button className="text-accent-lime text-xs font-semibold hover:text-white transition-colors flex items-center gap-1 justify-end w-full">
                        Analyze <ArrowUpRight size={14} />
                      </button>
                    </td>
                  </tr>
                );
              })}

              {/* Loading, failure and genuinely-empty are three different things. The table
                  used to say "No fields available" for all of them, including a 500. */}
              {sortedFields.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center text-text-muted">
                    {isLoading ? (
                      'Loading fields…'
                    ) : isError ? (
                      <span className="text-accent-red flex items-center justify-center gap-2">
                        <AlertTriangle size={14} />
                        Could not load fields. The list below is not empty — the request failed.
                      </span>
                    ) : (
                      'No fields available. Use the interactive map to register a new field.'
                    )}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>
    </div>
  );
};

// ---------------------------------------------------------------------------
// Field view (a field is selected)
// ---------------------------------------------------------------------------

const FieldAnalytics: React.FC = () => {
  const activeField = useActiveField()!;
  const setActiveField = useFleetStore((s) => s.setActiveField);
  const { sensors } = useFleetSensors();
  const { dashboard } = useActiveDashboard();

  const [range, setRange] = useState<AnalyticsRange>('24h');
  const [exporting, setExporting] = useState<ExportKind | null>(null);
  const [exportError, setExportError] = useState<string | null>(null);

  const { data: analytics, isLoading, isError, isFetching, refetch } = useAnalyticsData(activeField.id, range);

  const forecast = dashboard?.sources.weather.data?.forecast_days || [];
  const points = analytics?.points ?? NO_POINTS;
  const fieldSensors = sensors.filter((s) => s.field_id === activeField.id);
  const onlineFieldSensors = fieldSensors.filter((s) => isOnline(s.last_seen)).length;
  const health = healthPresentation(activeField.latest_health_score);

  const moistureDomain = useMemo(
    () => paddedDomain(points.flatMap((p) => [p.moistureMin, p.moistureMax].filter((v): v is number => v !== null))),
    [points]
  );
  const tempDomain = useMemo(
    () => paddedDomain(points.flatMap((p) => [p.temperatureMin, p.temperatureMax].filter((v): v is number => v !== null))),
    [points]
  );

  const handleExport = async (kind: ExportKind) => {
    setExporting(kind);
    setExportError(null);
    try {
      await exportService.downloadFieldCsv(activeField.id, activeField.name, kind);
    } catch (e: any) {
      setExportError(e?.message || 'Export failed. Please try again.');
    } finally {
      setExporting(null);
    }
  };

  return (
    <div className="flex flex-col gap-6 pb-10">
      {/* Field header + data export. The export endpoints existed server-side but were
          unreachable from the UI, so field history could not leave the platform. */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div>
          <button
            onClick={() => setActiveField(null)}
            className="text-xs text-text-muted hover:text-accent-lime transition-colors flex items-center gap-1 mb-1"
          >
            <ArrowLeft size={12} /> Back to fleet triage
          </button>
          <h2 className="text-xl font-extrabold text-text-main flex items-center gap-2.5">
            {activeField.name}
            <span
              className="text-[10px] font-bold px-2 py-0.5 rounded-full"
              style={{ background: `${health.color}22`, color: health.color }}
            >
              {health.label}
              {activeField.latest_health_score !== undefined && activeField.latest_health_score !== null
                ? ` · ${activeField.latest_health_score.toFixed(0)}`
                : ''}
            </span>
          </h2>
          <p className="text-[13px] text-text-muted mt-0.5 capitalize">
            {activeField.crop_type} · {Number.isFinite(activeField.area_ha) ? `${activeField.area_ha.toFixed(2)} ha` : 'area unknown'}
            {activeField.owner_name || activeField.owner_email ? ` · ${activeField.owner_name || activeField.owner_email}` : ''}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {EXPORT_KINDS.map((kind) => (
            <button
              key={kind.id}
              title={kind.description}
              disabled={exporting !== null}
              onClick={() => handleExport(kind.id)}
              className="btn-secondary text-xs py-1.5 px-3 flex items-center gap-1.5 disabled:opacity-50"
            >
              <Download size={13} />
              {exporting === kind.id ? 'Preparing…' : kind.label}
            </button>
          ))}
        </div>
      </div>
      {exportError && (
        <p className="text-xs text-accent-red flex items-center gap-1.5">
          <AlertTriangle size={13} /> {exportError}
        </p>
      )}

      {/* Provenance strip: how much real data is behind the charts below. Without this a
          single reading and a month of continuous telemetry draw equally confident lines. */}
      <GlassCard className="p-4 flex flex-wrap items-center gap-x-8 gap-y-3">
        <div className="flex items-center gap-2 mr-auto">
          <Database size={15} className="text-primary-light" />
          <span className="text-xs font-semibold text-text-main">Data behind these charts</span>
        </div>
        <div>
          <div className="text-sm font-bold text-text-main leading-tight">
            {onlineFieldSensors}/{fieldSensors.length}
          </div>
          <div className="text-[10px] text-text-muted">Probes online</div>
        </div>
        <div>
          <div className="text-sm font-bold text-text-main leading-tight">
            {analytics?.readingCount?.toLocaleString() ?? '--'}
          </div>
          <div className="text-[10px] text-text-muted">Readings in window</div>
        </div>
        <div>
          <div className="text-sm font-bold text-text-main leading-tight">
            {relativeTime(analytics?.lastReadingAt ?? null)}
          </div>
          <div className="text-[10px] text-text-muted">Newest reading</div>
        </div>
        <div>
          <div className={clsx(
            'text-sm font-bold leading-tight',
            (analytics?.gapCount ?? 0) > 0 ? 'text-accent-orange' : 'text-text-main'
          )}>
            {analytics?.gapCount ?? 0}
          </div>
          <div className="text-[10px] text-text-muted">Empty buckets</div>
        </div>

        <div className="flex items-center gap-2">
          {/* Range selector — the windows were previously fixed at 24h and 30d in code. */}
          <div className="flex rounded-md overflow-hidden border border-border-glass">
            {RANGE_OPTIONS.map((opt) => (
              <button
                key={opt.id}
                onClick={() => setRange(opt.id)}
                className={clsx(
                  'px-3 py-1 text-[11px] font-semibold transition-colors',
                  range === opt.id
                    ? 'bg-primary-medium/40 text-accent-lime'
                    : 'text-text-muted hover:text-text-main hover:bg-white/5'
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="btn-icon disabled:opacity-50"
            title="Refresh telemetry"
          >
            <RefreshCw size={14} className={isFetching ? 'animate-spin' : ''} />
          </button>
        </div>
      </GlassCard>

      {/* Row 2: moisture and soil temperature, each with its real observed spread. */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <GlassCard className="p-5">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Root-Zone Moisture</h3>
              <p className="text-xs text-text-muted">
                {ANALYTICS_RANGES[range].label} · mean with observed min–max spread
              </p>
            </div>
            <MetricBadge label={`${analytics?.probeCount ?? 0} probe${analytics?.probeCount === 1 ? '' : 's'}`} variant="info" size="sm" />
          </div>

          <ChartState
            isLoading={isLoading}
            isError={isError}
            isEmpty={!analytics?.hasMoisture}
            emptyMessage="No moisture readings in this window. Check that a probe is paired to this field and reporting."
          >
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={points}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="label" stroke="#9ca3af" fontSize={11} minTickGap={24} />
                <YAxis
                  stroke="#9ca3af"
                  fontSize={11}
                  domain={moistureDomain ?? ['auto', 'auto']}
                  unit="%"
                  width={48}
                />
                <Tooltip contentStyle={CHART_TOOLTIP} />
                <Legend wrapperStyle={{ fontSize: '11px' }} />
                {/* The band is the real spread across probes and sub-buckets, not a
                    derived second series. */}
                <Area
                  dataKey="moistureBand"
                  name="Observed range"
                  stroke="none"
                  fill="#568c48"
                  fillOpacity={0.22}
                  connectNulls={true}
                  isAnimationActive={false}
                />
                <Line
                  type="monotone"
                  dataKey="moisture"
                  name="Mean moisture (%)"
                  stroke="#9ad46c"
                  strokeWidth={2}
                  dot={false}
                  connectNulls={true}
                  isAnimationActive={false}
                />
              </ComposedChart>
            </ResponsiveContainer>
          </ChartState>
        </GlassCard>

        <GlassCard className="p-5">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Soil Temperature</h3>
              {/* The old subtitle promised "Surface (T0) vs 10cm Root-Zone (T10)". There is
                  no depth probe — that second line was the first minus 2.1 °C. */}
              <p className="text-xs text-text-muted">
                {ANALYTICS_RANGES[range].label} · DS18B20 mean with observed min–max spread
              </p>
            </div>
            <Thermometer size={18} className="text-accent-orange" />
          </div>

          <ChartState
            isLoading={isLoading}
            isError={isError}
            isEmpty={!analytics?.hasTemperature}
            emptyMessage="No temperature readings in this window. Check that a probe is paired to this field and reporting."
          >
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={points}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="label" stroke="#9ca3af" fontSize={11} minTickGap={24} />
                <YAxis
                  stroke="#9ca3af"
                  fontSize={11}
                  domain={tempDomain ?? ['auto', 'auto']}
                  unit="°"
                  width={48}
                />
                <Tooltip contentStyle={CHART_TOOLTIP} />
                <Legend wrapperStyle={{ fontSize: '11px' }} />
                <Area
                  dataKey="temperatureBand"
                  name="Observed range"
                  stroke="none"
                  fill="#fb923c"
                  fillOpacity={0.18}
                  connectNulls={true}
                  isAnimationActive={false}
                />
                <Line
                  type="monotone"
                  dataKey="temperature"
                  name="Mean soil temp (°C)"
                  stroke="#fb923c"
                  strokeWidth={2}
                  dot={false}
                  connectNulls={true}
                  isAnimationActive={false}
                />
              </ComposedChart>
            </ResponsiveContainer>
          </ChartState>
        </GlassCard>
      </div>

      {/* Row 3: nutrients and rainfall */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <GlassCard className="p-5">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Soil Nutrients</h3>
              <p className="text-xs text-text-muted">Latest N-P-K reading from a paired probe</p>
            </div>
            <FlaskConical size={18} className="text-accent-purple" />
          </div>

          {/* This chart used to plot npk ?? 0 against hardcoded "agronomic targets" of
              120/45/180, so a field with no NPK probe rendered as a catastrophic
              nitrogen deficiency. No NPK hardware is reporting → say that instead. */}
          <ChartState
            isLoading={isLoading}
            isError={isError}
            isEmpty={!analytics?.hasNutrients}
            height={200}
            emptyMessage="No probe on this field reports N-P-K. The paired hardware measures soil temperature and moisture only — a Modbus/RS485 nutrient probe would be needed to populate this."
          >
            <ResponsiveContainer width="100%" height="100%">
              {/* N, P and K share one unit (mg/kg) so they share one axis. EC is a
                  different unit entirely and gets its own tile below. */}
              <BarChart data={analytics?.nutrients ?? []}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="element" stroke="#9ca3af" fontSize={11} />
                <YAxis stroke="#9ca3af" fontSize={11} unit=" mg/kg" width={70} />
                <Tooltip contentStyle={CHART_TOOLTIP} />
                <Bar dataKey="current" name="Measured (mg/kg)" fill="#568c48" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </ChartState>

          {(analytics?.hasEc || analytics?.hasPh) && (
            <div className="flex gap-6 pt-3 mt-3 border-t border-border-subtle">
              {analytics?.hasEc && (
                <div>
                  <div className="text-sm font-bold text-text-main">{analytics.latestEc?.toFixed(2)} <span className="text-[10px] font-medium text-text-muted">mS/cm</span></div>
                  <div className="text-[10px] text-text-muted">EC salinity</div>
                </div>
              )}
              {analytics?.hasPh && (
                <div>
                  <div className="text-sm font-bold text-text-main">{analytics.latestPh?.toFixed(2)}</div>
                  <div className="text-[10px] text-text-muted">Soil pH</div>
                </div>
              )}
            </div>
          )}
        </GlassCard>

        <GlassCard className="p-5">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Rainfall Forecast (mm)</h3>
              <p className="text-xs text-text-muted">Weather provider forecast for this field</p>
            </div>
            <CloudRain size={18} className="text-accent-cyan" />
          </div>

          <ChartState
            isEmpty={forecast.length === 0}
            height={200}
            emptyMessage="No forecast available for this field yet."
          >
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={forecast}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="date" stroke="#9ca3af" fontSize={11} />
                <YAxis stroke="#9ca3af" fontSize={11} unit=" mm" width={56} />
                <Tooltip contentStyle={CHART_TOOLTIP} />
                <Bar dataKey="rain_mm" name="Expected rain (mm)" fill="#38bdf8" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </ChartState>
        </GlassCard>
      </div>
    </div>
  );
};

export const FleetAnalyticsView: React.FC = () => {
  const activeField = useActiveField();
  // Both branches are components, so hook order is stable across the switch — the previous
  // version called hooks and then returned early from the middle of one component.
  return activeField ? <FieldAnalytics key={activeField.id} /> : <FleetTriage />;
};
