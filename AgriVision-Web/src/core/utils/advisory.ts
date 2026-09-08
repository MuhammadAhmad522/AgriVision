import type { AdvisoryPriority } from '../types';

/** One definition of priority styling, shared by advisories and AI recommendations. */
export interface PriorityPresentation {
  label: string;
  color: string;
  badge: 'success' | 'warning' | 'danger' | 'info' | 'neutral';
}

export const PRIORITY_PRESENTATION: Record<AdvisoryPriority, PriorityPresentation> = {
  low: { label: 'Low', color: '#6b7280', badge: 'neutral' },
  normal: { label: 'Normal', color: '#568c48', badge: 'success' },
  high: { label: 'High', color: '#fb923c', badge: 'warning' },
  urgent: { label: 'Urgent', color: '#f87171', badge: 'danger' },
};

export const ADVISORY_PRIORITIES: AdvisoryPriority[] = ['low', 'normal', 'high', 'urgent'];

/** Maps a recommendation's own priority string onto the shared scale. */
export function recommendationPriority(priority?: string): PriorityPresentation {
  const key = (priority || '').toLowerCase();
  if (key === 'high') return PRIORITY_PRESENTATION.high;
  if (key === 'medium') return PRIORITY_PRESENTATION.high;
  if (key === 'low') return PRIORITY_PRESENTATION.low;
  return PRIORITY_PRESENTATION.normal;
}

/**
 * How long something has been waiting. An expert queue without an age column is a queue
 * people forget: the oldest item is the one most likely to have gone stale in the field.
 */
export function waitingFor(iso: string): { label: string; hours: number } {
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms)) return { label: 'unknown', hours: 0 };
  const hours = ms / 3_600_000;
  if (hours < 1) return { label: `${Math.max(1, Math.floor(ms / 60_000))}m`, hours };
  if (hours < 24) return { label: `${Math.floor(hours)}h`, hours };
  return { label: `${Math.floor(hours / 24)}d`, hours };
}

/** Review backlog severity. Advice about irrigation or pest risk decays fast. */
export function stalenessBand(hours: number): 'fresh' | 'aging' | 'stale' {
  if (hours < 24) return 'fresh';
  if (hours < 72) return 'aging';
  return 'stale';
}
