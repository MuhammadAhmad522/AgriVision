import { http } from '../api/http';
import type { AIRecommendation, ChatMessage, SeasonMemory } from '../types';

export class AdvisoryService {
  async getRecommendations(fieldId: string): Promise<AIRecommendation[]> {
    return await http.get<AIRecommendation[]>(`/api/fields/${fieldId}/recommendations`);
  }

  /** Read-only: null when the field has no crop journal yet (e.g. no plantation date set). */
  async getSeasonMemory(fieldId: string): Promise<SeasonMemory | null> {
    try {
      return await http.get<SeasonMemory>(`/api/fields/${fieldId}/season-memory`);
    } catch {
      return null;
    }
  }

  /** Forces an immediate AI re-analysis for the field (rate-limited server-side). */
  async triggerAIReasoning(fieldId: string): Promise<boolean> {
    try {
      await http.post(`/api/fields/${fieldId}/recommendations`);
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

  /** Read-only: the farmer's AI chat history for a field, for staff oversight. */
  async getFieldChatHistory(fieldId: string): Promise<ChatMessage[]> {
    return await http.get<ChatMessage[]>(`/api/fields/${fieldId}/chat`);
  }

  async getAgronomistGuidanceHistory(fieldId: string): Promise<ChatMessage[]> {
    return await http.get<ChatMessage[]>(`/api/fields/${fieldId}/agronomist-chat`);
  }

  async sendAgronomistGuidance(fieldId: string, message: string): Promise<{ user_message: ChatMessage; assistant_message: ChatMessage }> {
    const idempotencyKey = `web-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    return await http.post(`/api/fields/${fieldId}/agronomist-chat`, { message }, {
      headers: { 'Idempotency-Key': idempotencyKey },
    });
  }
}

export const advisoryService = new AdvisoryService();
