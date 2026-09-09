import { create } from 'zustand';

interface UIState {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  isSidebarOpen: boolean;
  setSidebarOpen: (isOpen: boolean) => void;
  isInspectorOpen: boolean;
  setInspectorOpen: (isOpen: boolean) => void;
}

export const useUIStore = create<UIState>((set) => ({
  activeTab: 'gis',
  setActiveTab: (tab) => set({ activeTab: tab }),
  isSidebarOpen: true,
  setSidebarOpen: (isOpen) => set({ isSidebarOpen: isOpen }),
  isInspectorOpen: true,
  setInspectorOpen: (isOpen) => set({ isInspectorOpen: isOpen }),
}));
