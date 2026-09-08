import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { advisoryService } from '../services/AdvisoryService';
import type { AdvisoryCreate } from '../types';

export function usePendingRecommendations() {
  return useQuery({
    queryKey: ['advisory', 'pending'],
    queryFn: () => advisoryService.getExpertPendingRecommendations(),
  });
}

export function useValidateRecommendation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, status, notes }: { id: string; status: 'approved' | 'rejected'; notes: string }) =>
      advisoryService.validateRecommendation(id, status, notes),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['advisory', 'pending'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
}

export function useTriggerReEvaluation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (fieldId: string) => {
      const ok = await advisoryService.triggerAIReasoning(fieldId);
      if (!ok) throw new Error('Could not trigger AI re-evaluation.');
      
      const triggeredAt = Date.now();
      for (let attempt = 0; attempt < 8; attempt++) {
        if (attempt > 0) await new Promise((resolve) => setTimeout(resolve, 3000));
        const recs = await advisoryService.getRecommendations(fieldId);
        if (recs.some((r) => new Date(r.created_at).getTime() > triggeredAt)) break;
      }
      return true;
    },
    onSuccess: (_, fieldId) => {
      queryClient.invalidateQueries({ queryKey: ['dashboard', fieldId] });
    }
  });
}

export function useAnalysisRun(recommendationId: string | undefined, enabled: boolean) {
  return useQuery({
    queryKey: ['advisory', 'analysis-run', recommendationId],
    queryFn: () => recommendationId ? advisoryService.getAnalysisRun(recommendationId) : null,
    enabled: enabled && !!recommendationId,
  });
}

export function useSeasonMemory(fieldId: string | undefined) {
  return useQuery({
    queryKey: ['advisory', 'memory', fieldId],
    queryFn: () => fieldId ? advisoryService.getSeasonMemory(fieldId) : null,
    enabled: !!fieldId,
  });
}

export function useChatHistory(fieldId: string | undefined) {
  return useQuery({
    queryKey: ['advisory', 'chat', fieldId],
    queryFn: () => fieldId ? advisoryService.getFieldChatHistory(fieldId) : [],
    enabled: !!fieldId,
  });
}

export function useGuidanceHistory(fieldId: string | undefined) {
  return useQuery({
    queryKey: ['advisory', 'guidance', fieldId],
    queryFn: () => fieldId ? advisoryService.getAgronomistGuidanceHistory(fieldId) : [],
    enabled: !!fieldId,
  });
}

export function useSendGuidance() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ fieldId, text }: { fieldId: string; text: string }) =>
      advisoryService.sendAgronomistGuidance(fieldId, text),
    onSuccess: (_, { fieldId }) => {
      queryClient.invalidateQueries({ queryKey: ['advisory', 'guidance', fieldId] });
    },
  });
}

export function useAISettings(enabled: boolean = true) {
  return useQuery({
    queryKey: ['settings', 'ai'],
    queryFn: () => advisoryService.getAISettings(),
    enabled
  });
}

export function useUpdateAISettings() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (settings: any) => advisoryService.updateAISettings(settings),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['settings', 'ai'] });
    },
  });
}

export function useCheckAIHealth() {
  return useMutation({
    mutationFn: () => advisoryService.checkAIHealth(),
  });
}

export function useAdvisories(fieldId: string | undefined) {
  return useQuery({
    queryKey: ['advisory', 'sent', fieldId],
    queryFn: () => (fieldId ? advisoryService.getAdvisories(fieldId) : []),
    enabled: !!fieldId,
  });
}

export function useSendAdvisory() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ fieldId, advisory }: { fieldId: string; advisory: AdvisoryCreate }) =>
      advisoryService.sendAdvisory(fieldId, advisory),
    onSuccess: (_, { fieldId }) => {
      queryClient.invalidateQueries({ queryKey: ['advisory', 'sent', fieldId] });
    },
  });
}
