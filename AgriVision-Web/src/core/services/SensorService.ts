import { http } from '../api/http';
import type { SensorDevice, SensorReading, SensorHealth } from '../types';

export interface VerifySensorResponse {
  is_verified: boolean;
  name?: string;
  last_seen?: string;
  message: string;
}

export interface PairSensorResponse {
  message: string;
  sensor: SensorDevice;
}

export class SensorService {
  async getDevices(filters?: { ownerId?: string; fieldId?: string; unassigned?: boolean }): Promise<SensorDevice[]> {
    const params = new URLSearchParams();
    if (filters?.ownerId) params.set('owner_id', filters.ownerId);
    if (filters?.fieldId) params.set('field_id', filters.fieldId);
    if (filters?.unassigned) params.set('unassigned', 'true');
    const suffix = params.toString() ? `?${params.toString()}` : '';
    return await http.get<SensorDevice[]>(`/api/sensors${suffix}`);
  }

  /** Reporting cadence, gaps and last values for one probe. */
  async getDeviceHealth(deviceId: string, hours = 24): Promise<SensorHealth> {
    return await http.get<SensorHealth>(`/api/sensors/${encodeURIComponent(deviceId)}/health?hours=${hours}`);
  }

  /** Attaches an already-paired probe to a field. Both must belong to the same farmer. */
  async assignToField(fieldId: string, deviceId: string, name?: string, sensorType = 'multi_sensor'): Promise<SensorDevice> {
    return await http.post<SensorDevice>(`/api/fields/${fieldId}/sensors`, {
      device_id: deviceId,
      name,
      sensor_type: sensorType,
    });
  }

  /** Removes a probe from a field but keeps its telemetry — unlike unpairing, which
   *  deletes the sensor record and cascades away every reading it ever took. */
  async detachFromField(fieldId: string, deviceId: string): Promise<void> {
    await http.delete(`/api/fields/${fieldId}/sensors/${encodeURIComponent(deviceId)}`);
  }

  async verifySensor(deviceId: string): Promise<VerifySensorResponse> {
    return await http.get<VerifySensorResponse>(`/api/sensors/verify/${encodeURIComponent(deviceId)}`);
  }

  /** `ownerId` pairs on a farmer's behalf. Without it a staff member claims the probe for
   *  their own account, and staff own no fields — so it could never be assigned anywhere. */
  async pairSensor(deviceId: string, ownerId?: string): Promise<PairSensorResponse> {
    return await http.post<PairSensorResponse>('/api/sensors/pair', {
      device_id: deviceId,
      ...(ownerId ? { owner_id: ownerId } : {}),
    });
  }

  async unpairSensor(deviceId: string): Promise<void> {
    await http.delete(`/api/sensors/${encodeURIComponent(deviceId)}`);
  }

  /**
   * `limit` must be sent explicitly: the endpoint defaults to 100 rows, which silently
   * truncated long windows — a 30-day request across two probes returned under two weeks
   * of buckets and the chart drew it as if that were the whole history.
   */
  async getFieldReadings<T = SensorReading>(
    fieldId: string,
    hours = 24,
    granularity = 'hourly',
    limit = 1000
  ): Promise<T[]> {
    const params = new URLSearchParams({
      granularity,
      hours: String(hours),
      limit: String(limit),
    });
    return await http.get<T[]>(`/api/fields/${fieldId}/sensor-readings?${params.toString()}`);
  }
}

export const sensorService = new SensorService();
