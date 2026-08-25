import { http } from '../api/http';
import type { Field, DashboardSources } from '../types';

export class FieldService {
  async getFields(): Promise<Field[]> {
    return await http.get<Field[]>('/api/fields');
  }

  async getFieldDashboard(fieldId: string): Promise<{ sources: DashboardSources; recommendations: any[] }> {
    return await http.get<{ sources: DashboardSources; recommendations: any[] }>(`/api/fields/${fieldId}/dashboard`);
  }
}

export const fieldService = new FieldService();
