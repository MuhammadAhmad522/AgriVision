import type { Field } from '../types';

/**
 * The single definition of field health used by the map choropleth, the fleet triage table
 * and the inspector, so a field that reads "at risk" in one place cannot read "healthy" in
 * another.
 *
 * Scores come from the backend's `latest_health_score` — the AI advisor's holistic 0-100
 * assessment, which already accounts for crop growth stage. Raw NDVI is deliberately not
 * used for triage: it is legitimately low right after planting and right before harvest, so
 * colouring by it would flag healthy fields as failing twice a season.
 */
export type HealthBand = 'critical' | 'at_risk' | 'watch' | 'healthy' | 'unknown';

export interface HealthPresentation {
  band: HealthBand;
  label: string;
  /** Hex, used for map fills where CSS variables are not available. */
  color: string;
  /** Tailwind text colour for list/panel rendering. */
  textClass: string;
}

const PRESENTATION: Record<HealthBand, HealthPresentation> = {
  critical: { band: 'critical', label: 'Critical', color: '#f87171', textClass: 'text-accent-red' },
  at_risk: { band: 'at_risk', label: 'At risk', color: '#fb923c', textClass: 'text-accent-orange' },
  watch: { band: 'watch', label: 'Watch', color: '#facc15', textClass: 'text-yellow-400' },
  healthy: { band: 'healthy', label: 'Healthy', color: '#568c48', textClass: 'text-accent-lime' },
  // A field the AI has not scored yet is grey, never green — "no assessment" must not be
  // presented as "no problem".
  unknown: { band: 'unknown', label: 'Not yet assessed', color: '#6b7280', textClass: 'text-text-muted' },
};

export function healthBand(score: number | null | undefined): HealthBand {
  if (score === null || score === undefined || Number.isNaN(score)) return 'unknown';
  if (score < 40) return 'critical';
  if (score < 60) return 'at_risk';
  if (score < 75) return 'watch';
  return 'healthy';
}

export function healthPresentation(score: number | null | undefined): HealthPresentation {
  return PRESENTATION[healthBand(score)];
}

/** Fields needing an agronomist's attention, worst first. Unscored fields are excluded —
 * they are surfaced separately rather than being ranked as if they were failing. */
export function fieldsNeedingAttention(fields: Field[]): Field[] {
  return fields
    .filter((f) => {
      const band = healthBand(f.latest_health_score);
      return band === 'critical' || band === 'at_risk';
    })
    .sort((a, b) => (a.latest_health_score ?? 0) - (b.latest_health_score ?? 0));
}

export const HEALTH_LEGEND: HealthPresentation[] = [
  PRESENTATION.critical,
  PRESENTATION.at_risk,
  PRESENTATION.watch,
  PRESENTATION.healthy,
  PRESENTATION.unknown,
];
