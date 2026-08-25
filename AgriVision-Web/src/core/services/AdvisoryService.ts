import { http } from '../api/http';
import type { AIRecommendation } from '../types';

export class AdvisoryService {
  async getRecommendations(fieldId: string): Promise<AIRecommendation[]> {
    return await http.get<AIRecommendation[]>(`/api/fields/${fieldId}/recommendations`);
  }

  async triggerAIReasoning(fieldId: string): Promise<boolean> {
    try {
      await http.post(`/api/fields/${fieldId}/data-refresh`);
      return true;
    } catch {
      return false;
    }
  }

  async getExpertPendingRecommendations(): Promise<AIRecommendation[]> {
    return await http.get<AIRecommendation[]>('/api/recommendations/expert/pending');
  }

  async validateRecommendation(
    recommendationId: string, 
    status: 'approved' | 'rejected', 
    notes?: string
  ): Promise<AIRecommendation> {
    return await http.post<AIRecommendation>(
      `/api/recommendations/${recommendationId}/expert-validate`,
      { status, notes }
    );
  }
}

export const advisoryService = new AdvisoryService();
