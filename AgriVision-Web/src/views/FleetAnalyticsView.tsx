import React from 'react';
import { useFleetStore } from '../core/store/fleetStore';
import { useIoTStore } from '../core/store/iotStore';
import { useAnalyticsData } from '../core/hooks/useAnalyticsData';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer
} from 'recharts';
import { Sprout, Droplets, FlaskConical, Thermometer, CloudRain, ArrowUpRight, AlertTriangle } from 'lucide-react';

export const FleetAnalyticsView: React.FC = () => {
  const fields = useFleetStore(s => s.allFields);
  const activeField = useFleetStore(s => s.activeField);
  const dashboardData = useIoTStore(s => s.dashboardData);

  const { data: analytics } = useAnalyticsData(activeField?.id);
  const moistureHistory = analytics?.moistureHistory || [];
  const npkData = analytics?.npkData || [];
  const soilTempData = analytics?.soilTempData || [];

  const forecast = dashboardData?.sources.weather.data?.forecast_days || [];

  const totalAcreage = fields.reduce((acc, f) => acc + (f.area_ha * 2.471), 0).toFixed(1);

  if (!activeField) {
    // Sort fields by health score (lowest first)
    const sortedFields = [...fields].sort((a, b) => {
      const scoreA = a.latest_health_score ?? 100;
      const scoreB = b.latest_health_score ?? 100;
      return scoreA - scoreB;
    });

    const activeFields = fields.filter(f => f.status === 'active');
    const needsAttention = sortedFields.filter(f => (f.latest_health_score ?? 100) < 70);

    return (
      <div className="flex flex-col gap-6 pb-10 animate-in fade-in">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h2 className="text-2xl font-extrabold text-text-main">Fleet Risk Triage</h2>
            <p className="text-sm text-text-muted mt-1">Macro-level overview of all active fields sorted by crop health risk.</p>
          </div>
          <div className="flex gap-4">
            <GlassCard className="px-4 py-2 flex items-center gap-3 border-accent-lime/30">
              <Sprout size={18} className="text-accent-lime" />
              <div>
                <div className="text-lg font-bold text-text-main leading-tight">{activeFields.length}</div>
                <div className="text-[10px] text-text-muted">Active Fields</div>
              </div>
            </GlassCard>
            <GlassCard className="px-4 py-2 flex items-center gap-3 border-accent-red/30">
              <AlertTriangle size={18} className="text-accent-red" />
              <div>
                <div className="text-lg font-bold text-accent-red leading-tight">{needsAttention.length}</div>
                <div className="text-[10px] text-accent-red/80">At Risk (&lt;70)</div>
              </div>
            </GlassCard>
          </div>
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
                  const score = field.latest_health_score ?? 100;
                  const isRisk = score < 70;
                  const setField = useFleetStore.getState().setActiveField;
                  
                  return (
                    <tr 
                      key={field.id} 
                      className="hover:bg-[#1a3a23]/50 transition-colors cursor-pointer group"
                      onClick={() => setField(field)}
                    >
                      <td className="px-6 py-4 font-medium flex items-center gap-3">
                        <div className={`w-2 h-2 rounded-full ${isRisk ? 'bg-accent-red shadow-[0_0_8px_rgba(248,113,113,0.8)]' : 'bg-accent-lime'}`} />
                        {field.name}
                      </td>
                      <td className="px-6 py-4 text-text-muted capitalize">{field.crop_type}</td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-24 h-2 bg-black/40 rounded-full overflow-hidden">
                            <div 
                              className={`h-full rounded-full ${isRisk ? 'bg-gradient-to-r from-accent-orange to-accent-red' : 'bg-gradient-to-r from-primary-medium to-accent-lime'}`} 
                              style={{ width: `${score}%` }} 
                            />
                          </div>
                          <span className={`font-bold ${isRisk ? 'text-accent-orange' : 'text-accent-lime'}`}>{score.toFixed(1)}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-xs text-text-muted hidden md:table-cell max-w-[250px] truncate" title={field.latest_health_rationale || 'Optimal growing conditions'}>
                        {field.latest_health_rationale || 'Optimal growing conditions'}
                      </td>
                      <td className="px-6 py-4 text-right">
                        <button className="text-accent-lime text-xs font-semibold hover:text-white transition-colors flex items-center gap-1 justify-end w-full">
                          Analyze <ArrowUpRight size={14} />
                        </button>
                      </td>
                    </tr>
                  );
                })}
                {sortedFields.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-6 py-12 text-center text-text-muted">
                      No fields available. Use the interactive map to register a new field.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </GlassCard>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6 pb-10">
      {/* Fleet KPI Banner */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Total Farm Acreage</span>
            <Sprout size={18} className="text-accent-lime" />
          </div>
          <div className="mt-3">
            <h3 className="text-[28px] font-extrabold text-text-main leading-tight">{totalAcreage} <span className="text-sm font-medium">Acres</span></h3>
            <p className="text-[11px] text-primary-light mt-1">Across {fields.length} Active Zones</p>
          </div>
        </GlassCard>

        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Canopy Health Index</span>
            <ArrowUpRight size={18} className="text-primary-light" />
          </div>
          <div className="mt-3">
            <h3 className="text-[28px] font-extrabold text-accent-lime leading-tight">0.78 <span className="text-sm font-medium">NDVI</span></h3>
            <p className="text-[11px] text-text-muted mt-1">+4.2% vs Previous Cycle</p>
          </div>
        </GlassCard>

        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Active Telemetry Probes</span>
            <Droplets size={18} className="text-accent-cyan" />
          </div>
          <div className="mt-3">
            <h3 className="text-[28px] font-extrabold text-text-main leading-tight">100% <span className="text-sm font-medium">Online</span></h3>
            <p className="text-[11px] text-accent-cyan mt-1">3 / 3 Sensors Paired</p>
          </div>
        </GlassCard>

        <GlassCard glow className="p-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-text-muted">Irrigation Stress Level</span>
            <MetricBadge label="Optimal" variant="success" />
          </div>
          <div className="mt-3">
            <h3 className="text-[28px] font-extrabold text-text-main leading-tight">36.2% <span className="text-sm font-medium">Vol. Moisture</span></h3>
            <p className="text-[11px] text-primary-light mt-1">Within 30–50% Target Zone</p>
          </div>
        </GlassCard>
      </div>

      {/* Row 2: 30-Day Moisture Area & 4-Bar NPK Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-[1.2fr_1fr] gap-5">
        {/* Moisture Area Chart */}
        <GlassCard className="p-5">
          <div className="flex justify-between items-center mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Root-Zone Moisture Retention (30 Days)</h3>
              <p className="text-xs text-text-muted">{activeField?.name} • Target Band 30%–50%</p>
            </div>
            <MetricBadge label="Area Fill" variant="info" />
          </div>

          <div className="h-[240px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={moistureHistory}>
                <defs>
                  <linearGradient id="moistGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#568c48" stopOpacity={0.5}/>
                    <stop offset="95%" stopColor="#568c48" stopOpacity={0.0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="day" stroke="#9ca3af" fontSize={11} />
                <YAxis stroke="#9ca3af" fontSize={11} domain={[10, 60]} />
                <Tooltip
                  contentStyle={{ background: '#112616', borderColor: '#568c48', borderRadius: '8px', color: '#fff' }}
                />
                <Area type="monotone" dataKey="moisture" stroke="#9ad46c" strokeWidth={3} fillOpacity={1} fill="url(#moistGrad)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </GlassCard>

        {/* NPK Comparison Chart */}
        <GlassCard className="p-5">
          <div className="flex justify-between items-center mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Soil Chemistry & NPK Profile</h3>
              <p className="text-xs text-text-muted">Current vs Agronomic Target</p>
            </div>
            <FlaskConical size={18} className="text-accent-purple" />
          </div>

          <div className="h-[240px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={npkData}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="element" stroke="#9ca3af" fontSize={11} />
                <YAxis stroke="#9ca3af" fontSize={11} />
                <Tooltip
                  contentStyle={{ background: '#112616', borderColor: '#568c48', borderRadius: '8px', color: '#fff' }}
                />
                <Bar dataKey="current" fill="#568c48" radius={[6, 6, 0, 0]} name="Current Level" />
                <Bar dataKey="target" fill="rgba(255,255,255,0.15)" radius={[6, 6, 0, 0]} name="Target Baseline" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </GlassCard>
      </div>

      {/* Row 3: Soil Temp Depth Profile & 5-Day Weather Forecast */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Soil Temp Dual Line */}
        <GlassCard className="p-5">
          <div className="flex justify-between items-center mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">Soil Thermal Profile (24h)</h3>
              <p className="text-xs text-text-muted">Surface Layer (T0) vs 10cm Root-Zone (T10)</p>
            </div>
            <Thermometer size={18} className="text-accent-orange" />
          </div>

          <div className="h-[200px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={soilTempData}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="time" stroke="#9ca3af" fontSize={11} />
                <YAxis stroke="#9ca3af" fontSize={11} domain={[10, 40]} />
                <Tooltip
                  contentStyle={{ background: '#112616', borderColor: '#568c48', borderRadius: '8px', color: '#fff' }}
                />
                <Line type="monotone" dataKey="surface" stroke="#fb923c" strokeWidth={2.5} name="Surface (T0 °C)" />
                <Line type="monotone" dataKey="depth10cm" stroke="#9ad46c" strokeWidth={2.5} name="10cm Depth (T10 °C)" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </GlassCard>

        {/* 5-Day Rainfall Outlook */}
        <GlassCard className="p-5">
          <div className="flex justify-between items-center mb-4">
            <div>
              <h3 className="text-base font-bold text-text-main">5-Day Rainfall Forecast (mm)</h3>
              <p className="text-xs text-text-muted">AgroMonitoring Precipitation Model</p>
            </div>
            <CloudRain size={18} className="text-accent-cyan" />
          </div>

          <div className="h-[200px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={forecast}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis dataKey="date" stroke="#9ca3af" fontSize={11} />
                <YAxis stroke="#9ca3af" fontSize={11} />
                <Tooltip
                  contentStyle={{ background: '#112616', borderColor: '#568c48', borderRadius: '8px', color: '#fff' }}
                />
                <Bar dataKey="rain_mm" fill="#38bdf8" radius={[6, 6, 0, 0]} name="Expected Rain (mm)" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </GlassCard>
      </div>
    </div>
  );
};
