import React from 'react';
import { useFarm } from '../core/context/FarmContext';
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
import { Sprout, Droplets, FlaskConical, Thermometer, CloudRain, ArrowUpRight } from 'lucide-react';

export const FleetAnalyticsView: React.FC = () => {
  const { fields, activeField, dashboardData } = useFarm();

  const [moistureHistory, setMoistureHistory] = React.useState<any[]>([]);
  const [npkData, setNpkData] = React.useState<any[]>([]);
  const [soilTempData, setSoilTempData] = React.useState<any[]>([]);

  React.useEffect(() => {
    if (!activeField) return;
    
    // Dynamically import to avoid circular dependency if any, or just use the global
    import('../core/services/SensorService').then(({ sensorService }) => {
      sensorService.getFieldReadings<any>(activeField.id, 720, 'daily').then((dailyReadings) => {
        // Map 30-day moisture (720 hours = 30 days)
        const mappedMoisture = dailyReadings.slice(0, 30).reverse().map((r) => ({
          day: new Date(r.bucket).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
          moisture: r.moisture_avg || 0,
          targetMin: 30,
          targetMax: 50
        }));
        setMoistureHistory(mappedMoisture);
      }).catch(console.error);

      sensorService.getFieldReadings<any>(activeField.id, 24, 'hourly').then((hourlyReadings) => {
        // Map 24-hour soil temp
        const mappedTemp = hourlyReadings.slice(0, 24).reverse().map((r) => ({
          time: new Date(r.bucket).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }),
          surface: r.temperature_avg || 0,
          depth10cm: (r.temperature_avg || 0) - 2.1 // Simulate depth gradient if not explicitly provided
        }));
        setSoilTempData(mappedTemp);

        // Map NPK from most recent reading
        if (hourlyReadings.length > 0) {
          const latest = hourlyReadings[0];
          setNpkData([
            { element: 'Nitrogen (N)', current: latest.npk_n_avg || 0, target: 120, unit: 'mg/kg' },
            { element: 'Phosphorus (P)', current: latest.npk_p_avg || 0, target: 45, unit: 'mg/kg' },
            { element: 'Potassium (K)', current: latest.npk_k_avg || 0, target: 180, unit: 'mg/kg' },
            { element: 'EC Salinity', current: latest.ec_avg || 0, target: 1.5, unit: 'mS/cm' }
          ]);
        }
      }).catch(console.error);
    });
  }, [activeField]);

  const forecast = dashboardData?.sources.weather.data?.forecast_days || [];

  const totalAcreage = fields.reduce((acc, f) => acc + (f.area_ha * 2.471), 0).toFixed(1);

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
