import { http } from '../api/http';
import type { SensorDevice, SensorReading } from '../types';

export class SensorService {
  async getDevices(): Promise<SensorDevice[]> {
    return await http.get<SensorDevice[]>('/api/sensors');
  }

  async pairSensor(deviceId: string, fieldId: string): Promise<boolean> {
    try {
      await http.post('/api/sensors/pair', { device_id: deviceId, field_id: fieldId });
      return true;
    } catch {
      return false;
    }
  }

  async getFieldReadings<T = SensorReading>(fieldId: string, hours = 24, granularity = 'hourly'): Promise<T[]> {
    return await http.get<T[]>(`/api/fields/${fieldId}/sensor-readings?granularity=${granularity}&hours=${hours}`);
  }
}

export const sensorService = new SensorService();
