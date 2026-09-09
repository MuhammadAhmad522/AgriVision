import type { Field, SensorDevice, DashboardSources, AIRecommendation } from '../types';
import { HttpClient } from './http';

export class AgriApiClient {
  private http: HttpClient;

  constructor() {
    this.http = new HttpClient();
  }

  getBaseURL(): string {
    return this.http.getBaseURL();
  }

  async fetchFields(): Promise<Field[]> {
    return await this.http.get<Field[]>('/api/fields');
  }

  async fetchDashboard(fieldId: string): Promise<{ sources: DashboardSources; recommendations: AIRecommendation[] }> {
    return await this.http.get<{ sources: DashboardSources; recommendations: AIRecommendation[] }>(`/api/fields/${fieldId}/dashboard`);
  }

  async fetchSensors(): Promise<SensorDevice[]> {
    return await this.http.get<SensorDevice[]>('/api/sensors');
  }
}

export const apiClient = new AgriApiClient();
