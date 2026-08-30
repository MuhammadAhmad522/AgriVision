import React, { useState } from 'react';
import { useFarm } from '../core/context/FarmContext';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { Radio, Battery, Wifi, Plus, Terminal } from 'lucide-react';

// Live tier: raw IoT telemetry only. 10s matches the fast end of iOS's sensor-refresh
// range (DashboardViewModel's dashboardRefreshInterval) — this is the one kind of data
// in the app that's genuinely real-time (MQTT-pushed), so a short fixed interval is
// correct here, unlike a full dashboard/recommendation re-fetch.
const SENSOR_POLL_INTERVAL_MS = 10000;

export const IoTHardwareView: React.FC = () => {
  const { sensors, fields, activeField } = useFarm();
  const [showPairModal, setShowPairModal] = useState(false);
  const [newDeviceId, setNewDeviceId] = useState('');

  const [mqttPackets, setMqttPackets] = useState<any[]>([]);

  // Poll for raw readings to simulate live MQTT stream
  React.useEffect(() => {
    let interval: number | ReturnType<typeof setTimeout>;

    const fetchLatest = () => {
      const fieldId = activeField?.id ?? fields[0]?.id; // fall back only if nothing is selected yet
      if (!fieldId) return;

      import('../core/services/SensorService').then(({ sensorService }) => {
        sensorService.getFieldReadings<any>(fieldId, 1, 'raw').then((readings) => {
          const formatted = readings.slice(0, 10).map((r) => ({
            topic: `agri/sensors/${r.sensor_id}/telemetry`,
            payload: JSON.stringify({ temp: r.temperature, moist: r.moisture, ph: r.ph, n: r.npk_n }),
            time: new Date(r.time).toLocaleTimeString(undefined, { hour12: false })
          }));
          setMqttPackets(formatted);
        }).catch(console.error);
      });
    };

    fetchLatest();
    interval = setInterval(fetchLatest, SENSOR_POLL_INTERVAL_MS);

    return () => clearInterval(interval);
  }, [fields, activeField]);

  return (
    <div className="flex flex-col gap-6 pb-10">
      {/* Header with Provision Button */}
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-[22px] font-extrabold text-text-main">IoT Hardware & Sensor Fleet</h2>
          <p className="text-[13px] text-text-muted mt-1">
            Real-time RS485 & wireless sensor nodes communicating via MQTT Broker (:1883)
          </p>
        </div>

        <button onClick={() => setShowPairModal(true)} className="btn-primary flex items-center gap-2">
          <Plus size={16} />
          <span>Provision New Sensor Node</span>
        </button>
      </div>

      {/* Hardware Fleet Table */}
      <GlassCard className="p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left text-[13px]">
            <thead>
              <tr className="border-b border-border-glass text-text-muted">
                <th className="p-4 font-semibold">Device Node ID</th>
                <th className="p-4 font-semibold">Assigned Zone</th>
                <th className="p-4 font-semibold">Probe Sensor Type</th>
                <th className="p-4 font-semibold">Battery %</th>
                <th className="p-4 font-semibold">Signal RSSI</th>
                <th className="p-4 font-semibold">Status</th>
                <th className="p-4 font-semibold">Last Telemetry</th>
              </tr>
            </thead>
            <tbody>
              {sensors.map((sensor) => {
                const assignedField = fields.find((f) => f.id === sensor.field_id);
                // Calculate online status based on 1-minute threshold
                const isOnline = sensor.last_seen 
                  ? (new Date().getTime() - new Date(sensor.last_seen).getTime()) < 60000 
                  : false;
                
                return (
                  <tr
                    key={sensor.id}
                    className="border-b border-white/5 transition-colors hover:bg-white/5"
                  >
                    <td className="p-4 font-bold text-text-main">
                      <div className="flex items-center gap-2">
                        <Radio size={16} className="text-accent-lime" />
                        {sensor.device_id}
                      </div>
                    </td>
                    <td className="p-4 font-semibold text-accent-lime">
                      {assignedField?.name || 'Unassigned'}
                    </td>
                    <td className="p-4 text-text-muted capitalize">
                      {sensor.sensor_type?.replace('_', ' ')}
                    </td>
                    <td className="p-4">
                      <div className="flex items-center gap-1.5">
                        <Battery size={15} className={(sensor.battery_level || 0) > 50 ? 'text-accent-lime' : 'text-accent-orange'} />
                        <span className="font-semibold text-text-main">{sensor.battery_level || 0}%</span>
                      </div>
                    </td>
                    <td className="p-4">
                      <div className="flex items-center gap-1.5 text-text-muted">
                        <Wifi size={14} />
                        <span>-65 dBm</span> {/* Fake RSSI since backend drops it */}
                      </div>
                    </td>
                    <td className="p-4">
                      <MetricBadge
                        label={isOnline ? 'Active' : 'Warning'}
                        variant={isOnline ? 'success' : 'warning'}
                        size="sm"
                      />
                    </td>
                    <td className="p-4 text-text-dim">
                      {sensor.last_seen ? new Date(sensor.last_seen).toLocaleString() : 'Never'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </GlassCard>

      {/* Live MQTT Stream Inspector */}
      <GlassCard className="p-5">
        <div className="flex justify-between items-center mb-3.5">
          <div className="flex items-center gap-2">
            <Terminal size={18} className="text-accent-lime" />
            <h3 className="text-[15px] font-bold text-text-main">Live Mosquitto MQTT Stream (:1883)</h3>
          </div>
          <span className="text-[11px] text-primary-light font-mono">
            TOPIC: agri/sensors/+/telemetry
          </span>
        </div>

        <div className="bg-black/45 border border-border-subtle rounded-md p-3.5 font-mono text-xs flex flex-col gap-2 h-40 overflow-y-auto">
          {mqttPackets.length === 0 ? (
            <span className="text-text-muted italic">Waiting for incoming telemetry...</span>
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

      {/* Provision Modal */}
      {showPairModal && (
        <div className="fixed inset-0 bg-black/75 backdrop-blur-md flex items-center justify-center z-[100]">
          <div className="w-[440px] bg-brand-charcoal-green border border-border-glass-bright rounded-xl p-6 shadow-[0_20px_40px_rgba(0,0,0,0.6)]">
            <h3 className="text-lg font-extrabold text-text-main mb-1.5">Pair New Hardware Node</h3>
            <p className="text-xs text-text-muted mb-4.5 leading-relaxed">
              Enter the unique hardware MAC or QR code printed on the physical sensor gateway.
            </p>

            <div className="flex flex-col gap-3.5">
              <div>
                <label className="text-[11px] font-semibold text-text-muted block mb-1">Device Identifier</label>
                <input
                  type="text"
                  placeholder="e.g. AGRI-PROBE-04"
                  value={newDeviceId}
                  onChange={(e) => setNewDeviceId(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-sm bg-black/30 border border-border-glass text-white text-sm outline-none focus:border-primary-light transition-colors"
                />
              </div>

              <div className="flex justify-end gap-2.5 mt-2.5">
                <button onClick={() => setShowPairModal(false)} className="btn-secondary px-5">
                  Cancel
                </button>
                <button
                  onClick={() => {
                    setShowPairModal(false);
                    setNewDeviceId('');
                  }}
                  className="btn-primary px-5"
                >
                  Verify & Pair
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
