import { useQuery } from '@tanstack/react-query';
import { sensorService } from '../services/SensorService';
import type { SensorReading } from '../types';

export interface MqttPacket {
  topic: string;
  payload: string;
  time: string;
}

export function useRealtimeTelemetry(fieldId: string | undefined, intervalMs = 10000) {
  const query = useQuery({
    queryKey: ['telemetry', fieldId],
    queryFn: async () => {
      if (!fieldId) return [];
      const readings = await sensorService.getFieldReadings<SensorReading>(fieldId, 1, 'raw');
      return readings.slice(0, 10).map((r) => ({
        topic: `agri/sensors/${r.sensor_id}/telemetry`,
        payload: JSON.stringify({ temp: r.temperature, moist: r.moisture, ph: r.ph, n: r.npk_n }),
        time: new Date(r.time).toLocaleTimeString(undefined, { hour12: false })
      }));
    },
    enabled: !!fieldId,
    refetchInterval: intervalMs,
  });

  return query.data || [];
}
