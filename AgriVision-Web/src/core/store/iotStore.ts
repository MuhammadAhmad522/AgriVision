import { create } from 'zustand';
import type { SensorDevice, DashboardPayload } from '../types';

interface IoTState {
  sensors: SensorDevice[];
  dashboardData: DashboardPayload | null;
  loadingDashboard: boolean;
  
  setSensors: (sensors: SensorDevice[]) => void;
  setDashboardData: (data: DashboardPayload | null) => void;
  setLoadingDashboard: (loading: boolean) => void;
}

export const useIoTStore = create<IoTState>((set) => ({
  sensors: [],
  dashboardData: null,
  loadingDashboard: false,

  setSensors: (sensors) => set({ sensors }),
  setDashboardData: (data) => set({ dashboardData: data }),
  setLoadingDashboard: (loading) => set({ loadingDashboard: loading }),
}));
