import { http } from '../api/http';
import type { DashboardPayload, Field } from '../types';

export class FieldService {
  async getFields(): Promise<Field[]> {
    return await http.get<Field[]>('/api/fields');
  }

  /** Staff-only: browse every field, not just ones the current user owns. */
  async getAllFields(): Promise<Field[]> {
    return await http.get<Field[]>('/api/fields?admin_view=true');
  }

  async getFieldDashboard(fieldId: string): Promise<DashboardPayload> {
    return await http.get<DashboardPayload>(`/api/fields/${fieldId}/dashboard`);
  }
}

export const fieldService = new FieldService();
