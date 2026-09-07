import { useQuery } from '@tanstack/react-query';
import { sensorService } from '../services/SensorService';
import type { SensorReadingHourly } from '../types';

export function useAnalyticsData(fieldId: string | undefined) {
  return useQuery({
    queryKey: ['analytics', fieldId],
    queryFn: async () => {
      if (!fieldId) return null;
      
      const [dailyReadings, hourlyReadings] = await Promise.all([
        sensorService.getFieldReadings<SensorReadingHourly>(fieldId, 720, 'daily'),
        sensorService.getFieldReadings<SensorReadingHourly>(fieldId, 24, 'hourly')
      ]);

      const moistureHistory = dailyReadings.slice(0, 30).reverse().map((r) => ({
        day: new Date(r.bucket).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
        moisture: r.moisture_avg || 0,
        targetMin: 30,
        targetMax: 50
      }));

      const soilTempData = hourlyReadings.slice(0, 24).reverse().map((r) => ({
        time: new Date(r.bucket).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }),
        surface: r.temperature_avg || 0,
        depth10cm: (r.temperature_avg || 0) - 2.1
      }));

      let npkData: any[] = [];
      if (hourlyReadings.length > 0) {
        const latest = hourlyReadings[0];
        npkData = [
          { element: 'Nitrogen (N)', current: latest.npk_n_avg || 0, target: 120, unit: 'mg/kg' },
          { element: 'Phosphorus (P)', current: latest.npk_p_avg || 0, target: 45, unit: 'mg/kg' },
          { element: 'Potassium (K)', current: latest.npk_k_avg || 0, target: 180, unit: 'mg/kg' },
          { element: 'EC Salinity', current: latest.ec_avg || 0, target: 1.5, unit: 'mS/cm' }
        ];
      }

      return { moistureHistory, soilTempData, npkData };
    },
    enabled: !!fieldId,
  });
}
