import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { Field, SensorDevice, DashboardPayload } from '../types';
import { fieldService } from '../services/FieldService';
import { sensorService } from '../services/SensorService';
import { advisoryService } from '../services/AdvisoryService';
import { useAuth } from '../auth/AuthContext';

interface FarmContextType {
  fields: Field[];
  activeField: Field | null;
  setActiveField: (field: Field) => void;
  dashboardData: DashboardPayload | null;
  sensors: SensorDevice[];
  loading: boolean;
  refreshData: () => Promise<void>;
  refreshActiveFieldData: () => Promise<void>;
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const FarmContext = createContext<FarmContextType | undefined>(undefined);

export const FarmProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user } = useAuth();
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';
  const [fields, setFields] = useState<Field[]>([]);
  const [activeField, setActiveField] = useState<Field | null>(null);
  const [dashboardData, setDashboardData] = useState<DashboardPayload | null>(null);
  const [sensors, setSensors] = useState<SensorDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('gis');

  const refreshData = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      // Staff (admin/agronomist) review every farmer's fields, not just their own.
      const fieldList = isStaff ? await fieldService.getAllFields() : await fieldService.getFields();
      setFields(fieldList);

      // We only set the active field if it's not already set, or if we want to ensure it's valid.
      // The actual dashboard/recommendation data hydration is handled exclusively by the activeField useEffect.
      setActiveField((prev) => prev || fieldList[0] || null);

      const sensorList = await sensorService.getDevices();
      setSensors(sensorList);
    } catch (err) {
      console.error('Failed to load farm data', err);
    } finally {
      setLoading(false);
    }
  }, [user, isStaff]);

  const loadActiveFieldData = useCallback(async () => {
    if (!activeField) return;
    const [dashboard, recs] = await Promise.all([
      fieldService.getFieldDashboard(activeField.id),
      advisoryService.getRecommendations(activeField.id)
    ]);
    setDashboardData({ sources: dashboard.sources, advisor: dashboard.advisor, recommendations: recs });
  }, [activeField]);

  useEffect(() => {
    if (user) {
      refreshData();
    }
  }, [user]);

  useEffect(() => {
    loadActiveFieldData();
  }, [loadActiveFieldData]);

  // Reactive tier — matches iOS's DashboardViewModel full-dashboard poll and the backend's own
  // AGRO_WORKER_SCAN_SECONDS (5 min): polling faster can't surface anything the backend hasn't
  // itself noticed yet. No fast/sensor tier needed here — staff review, they don't need
  // 15s-fresh raw telemetry the way the farmer-facing app does.
  useEffect(() => {
    if (!activeField) return;
    const interval = setInterval(loadActiveFieldData, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [activeField, loadActiveFieldData]);

  return (
    <FarmContext.Provider
      value={{
        fields,
        activeField,
        setActiveField,
        dashboardData,
        sensors,
        loading,
        refreshData,
        refreshActiveFieldData: loadActiveFieldData,
        activeTab,
        setActiveTab
      }}
    >
      {children}
    </FarmContext.Provider>
  );
};

export const useFarm = () => {
  const context = useContext(FarmContext);
  if (!context) {
    throw new Error('useFarm must be used within a FarmProvider');
  }
  return context;
};
