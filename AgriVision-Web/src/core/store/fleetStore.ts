import { create } from 'zustand';
import type { Field } from '../types';

export interface Client {
  id: string;
  email: string;
}

interface FleetState {
  allFields: Field[];
  activeClient: Client | null;
  activeField: Field | null;
  loading: boolean;
  
  // Actions
  setAllFields: (fields: Field[]) => void;
  setActiveClient: (client: Client | null) => void;
  setActiveField: (field: Field | null) => void;
  setLoading: (loading: boolean) => void;
}

export const useFleetStore = create<FleetState>((set) => ({
  allFields: [],
  activeClient: null,
  activeField: null,
  loading: false,

  setAllFields: (fields) => set({ allFields: fields }),
  
  setActiveClient: (client) => set((state) => {
    // If we switch clients, and the active field doesn't belong to the new client, clear it
    let newActiveField = state.activeField;
    if (client && newActiveField && newActiveField.owner_id !== client.id) {
      newActiveField = null;
    }
    return { activeClient: client, activeField: newActiveField };
  }),
  
  setActiveField: (field) => set((state) => {
    if (field && field.owner_id && state.activeClient?.id !== field.owner_id) {
      return { 
        activeField: field, 
        activeClient: { id: field.owner_id, email: field.owner_email || 'Unknown User' } 
      };
    }
    return { activeField: field };
  }),
  setLoading: (loading) => set({ loading }),
}));

import { createSelector } from 'reselect';

// Derived Selectors
export const selectAllFields = (state: FleetState) => state.allFields;
export const selectActiveClient = (state: FleetState) => state.activeClient;

export const selectClients = createSelector(
  [selectAllFields],
  (allFields): Client[] => {
    const map = new Map<string, string>();
    allFields.forEach(f => {
      if (f.owner_id && f.owner_email) {
        map.set(f.owner_id, f.owner_email);
      }
    });
    return Array.from(map.entries()).map(([id, email]) => ({ id, email }));
  }
);

export const selectFilteredFields = createSelector(
  [selectAllFields, selectActiveClient],
  (allFields, activeClient): Field[] => {
    if (!activeClient) return allFields;
    return allFields.filter(f => f.owner_id === activeClient.id);
  }
);
