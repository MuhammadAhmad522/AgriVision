import { http } from '../api/http';
import type { AIRecommendation, AnalysisRunDetail, ChatMessage, SeasonMemory, AISettings, AIHealth, Advisory, AdvisoryCreate, GuidanceDirective, GuidanceMutationResult } from '../types';

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

  /** The model/prompt/policy version and context snapshot behind one recommendation.
   * Read-only: null when the recommendation predates analysis-run tracking or the run
   * record itself was pruned. */
  async getAnalysisRun(recommendationId: string): Promise<AnalysisRunDetail | null> {
    try {
      return await http.get<AnalysisRunDetail>(`/api/recommendations/${recommendationId}/analysis-run`);
    } catch {
      return null;
    }
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

  /** Durable standing guidance that shapes this field's AI recommendation engine. */
  async getGuidance(fieldId: string): Promise<GuidanceDirective[]> {
    return await http.get<GuidanceDirective[]>(`/api/fields/${fieldId}/guidance`);
  }

  async addGuidance(fieldId: string, text: string): Promise<GuidanceMutationResult> {
    return await http.post<GuidanceMutationResult>(`/api/fields/${fieldId}/guidance`, { text });
  }

  async retractGuidance(fieldId: string, directiveId: string): Promise<GuidanceMutationResult> {
    return await http.delete<GuidanceMutationResult>(`/api/fields/${fieldId}/guidance/${directiveId}`);
  }

  /**
   * Sends advice straight to the field owner's iOS notification inbox. Until this existed
   * the only farmer-facing message the platform could produce was the automatic line
   * emitted when a recommendation was reviewed — an agronomist had no way to say anything
   * of their own.
   */
  async sendAdvisory(fieldId: string, advisory: AdvisoryCreate): Promise<Advisory> {
    return await http.post<Advisory>(`/api/fields/${fieldId}/advisories`, advisory);
  }

  /** What has already been sent on this field, so advice is not repeated or contradicted. */
  async getAdvisories(fieldId: string): Promise<Advisory[]> {
    return await http.get<Advisory[]>(`/api/fields/${fieldId}/advisories`);
  }

  async getAISettings(): Promise<AISettings> {
    return await http.get<AISettings>('/api/admin/settings/ai');
  }

  async updateAISettings(settings: AISettings): Promise<AISettings> {
    return await http.put<AISettings>('/api/admin/settings/ai', settings);
  }

  /** Live probe: issues one tiny generation call against the active provider. */
  async checkAIHealth(): Promise<AIHealth> {
    return await http.get<AIHealth>('/api/admin/settings/ai/health');
  }
}

export const advisoryService = new AdvisoryService();
