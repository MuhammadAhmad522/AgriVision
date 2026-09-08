import { create } from 'zustand';
import type { Field } from '../types';

export interface Client {
  id: string;
  email: string;
  /** Farmer's display name; may be undefined — UI falls back to email. */
  name?: string | null;
}

/** How a farmer should be labelled in the UI: their name if known, otherwise their email. */
export function clientLabel(c: Pick<Client, 'email' | 'name'> | null | undefined): string {
  if (!c) return '';
  return (c.name && c.name.trim()) || c.email || 'Unknown User';
}

/**
 * Selection state only.
 *
 * This store deliberately holds no server data. It previously mirrored the whole field
 * list (and the sensor list, and the dashboard payload) out of TanStack Query via
 * useEffect, which created two sources of truth for the same rows. The visible symptom
 * was a stale active field: `activeField` was an object snapshot taken at click time, so
 * when the fields query refetched and a field's `latest_health_score` changed, the map
 * and the inspector kept rendering the score from whenever the user last clicked. The
 * mirror also swallowed query error state, so a failed /api/fields request was
 * indistinguishable from an empty estate.
 *
 * The selection is now an id. `useActiveField()` resolves it against the live query data
 * on every render, so what you see is always the current row.
 */
interface FleetSelectionState {
  activeFieldId: string | null;
  activeClientId: string | null;

  setActiveField: (field: Field | null) => void;
  setActiveFieldId: (id: string | null) => void;
  setActiveClient: (client: Client | null) => void;
  reset: () => void;
}

export const useFleetStore = create<FleetSelectionState>((set, get) => ({
  activeFieldId: null,
  activeClientId: null,

  // Selecting a field also focuses its owner, so the header dropdown follows a map click.
  setActiveField: (field) =>
    set(
      field
        ? { activeFieldId: field.id, activeClientId: field.owner_id ?? get().activeClientId }
        : { activeFieldId: null }
    ),

  setActiveFieldId: (id) => set({ activeFieldId: id }),

  // No imperative "clear the field if it belongs to someone else" here: that
  // reconciliation is derived in useActiveField, where the field list is available.
  setActiveClient: (client) => set({ activeClientId: client?.id ?? null }),

  reset: () => set({ activeFieldId: null, activeClientId: null }),
}));
