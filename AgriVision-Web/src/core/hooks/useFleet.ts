import { useMemo } from 'react';
import { useFleetStore, type Client } from '../store/fleetStore';
import { useFields, useSensors, useDashboard } from './useFarmQueries';
import type { Field, SensorDevice, DashboardPayload } from '../types';

/**
 * The single read API for fleet server state.
 *
 * Views call these instead of reading a Zustand mirror. TanStack Query owns the data and
 * its lifecycle (cache, refetch, error, in-flight), Zustand owns only which field and
 * which farmer are selected. That split is what makes an active field's health score
 * refresh on its own, and what lets a view distinguish "request failed" from "no fields".
 */

// Stable identities so a consumer's useMemo/useEffect deps don't churn on every render
// while a query is still loading.
const NO_FIELDS: Field[] = [];
const NO_SENSORS: SensorDevice[] = [];

export interface FleetFieldsResult {
  fields: Field[];
  isLoading: boolean;
  isFetching: boolean;
  isError: boolean;
  error: unknown;
  refetch: () => void;
  dataUpdatedAt: number;
}

/** Every field the signed-in user may see, unfiltered. */
export function useFleetFields(): FleetFieldsResult {
  const query = useFields();
  return {
    fields: query.data ?? NO_FIELDS,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    isError: query.isError,
    error: query.error,
    refetch: query.refetch,
    dataUpdatedAt: query.dataUpdatedAt,
  };
}

/** Fields narrowed to the farmer picked in the header. */
export function useVisibleFields(): FleetFieldsResult {
  const result = useFleetFields();
  const activeClientId = useFleetStore((s) => s.activeClientId);

  const fields = useMemo(() => {
    if (!activeClientId) return result.fields;
    return result.fields.filter((f) => f.owner_id === activeClientId);
  }, [result.fields, activeClientId]);

  return { ...result, fields };
}

/**
 * The selected field, resolved against live query data rather than an object captured at
 * click time. Returns null when the selection no longer exists (deleted, or filtered out
 * by the active farmer), which replaces the store's old imperative clearing.
 */
export function useActiveField(): Field | null {
  const { fields } = useFleetFields();
  const activeFieldId = useFleetStore((s) => s.activeFieldId);
  const activeClientId = useFleetStore((s) => s.activeClientId);

  return useMemo(() => {
    if (!activeFieldId) return null;
    const field = fields.find((f) => f.id === activeFieldId);
    if (!field) return null;
    if (activeClientId && field.owner_id && field.owner_id !== activeClientId) return null;
    return field;
  }, [fields, activeFieldId, activeClientId]);
}

/** Distinct farmers derived from the fields this user can see. */
export function useClients(): Client[] {
  const { fields } = useFleetFields();
  return useMemo(() => {
    const byId = new Map<string, Client>();
    for (const f of fields) {
      if (f.owner_id && f.owner_email && !byId.has(f.owner_id)) {
        byId.set(f.owner_id, { id: f.owner_id, email: f.owner_email, name: f.owner_name ?? null });
      }
    }
    return Array.from(byId.values()).sort((a, b) =>
      (a.name || a.email).localeCompare(b.name || b.email)
    );
  }, [fields]);
}

export function useActiveClient(): Client | null {
  const clients = useClients();
  const activeClientId = useFleetStore((s) => s.activeClientId);
  return useMemo(
    () => (activeClientId ? clients.find((c) => c.id === activeClientId) ?? null : null),
    [clients, activeClientId]
  );
}

export interface FleetSensorsResult {
  sensors: SensorDevice[];
  isLoading: boolean;
  isFetching: boolean;
  isError: boolean;
  refetch: () => void;
  dataUpdatedAt: number;
}

export function useFleetSensors(): FleetSensorsResult {
  const query = useSensors();
  return {
    sensors: query.data ?? NO_SENSORS,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    isError: query.isError,
    refetch: query.refetch,
    dataUpdatedAt: query.dataUpdatedAt,
  };
}

export interface ActiveDashboardResult {
  dashboard: DashboardPayload | null;
  isLoading: boolean;
  isError: boolean;
}

/**
 * Dashboard payload for the selected field. Safe to call from several components at once —
 * the query key is shared, so they de-duplicate onto one request instead of the old
 * pattern of one component fetching and writing to a store the others read.
 */
export function useActiveDashboard(): ActiveDashboardResult {
  const activeField = useActiveField();
  const query = useDashboard(activeField?.id ?? null);
  return {
    dashboard: query.data ?? null,
    isLoading: query.isLoading,
    isError: query.isError,
  };
}
