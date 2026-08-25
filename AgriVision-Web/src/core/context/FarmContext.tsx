import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { Field, SensorDevice, DashboardSources, AIRecommendation } from '../types';
import { fieldService } from '../services/FieldService';
import { sensorService } from '../services/SensorService';
import { advisoryService } from '../services/AdvisoryService';
import { useAuth } from '../auth/AuthContext';

interface FarmContextType {
  fields: Field[];
  activeField: Field | null;
  setActiveField: (field: Field) => void;
  dashboardData: { sources: DashboardSources; recommendations: AIRecommendation[] } | null;
  sensors: SensorDevice[];
  loading: boolean;
  refreshData: () => Promise<void>;
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const FarmContext = createContext<FarmContextType | undefined>(undefined);

export const FarmProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user } = useAuth();
  const [fields, setFields] = useState<Field[]>([]);
  const [activeField, setActiveField] = useState<Field | null>(null);
  const [dashboardData, setDashboardData] = useState<{ sources: DashboardSources; recommendations: AIRecommendation[] } | null>(null);
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
      const fieldList = await fieldService.getFields();
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
  }, [user]);

  useEffect(() => {
    if (user) {
      refreshData();
    }
  }, [user]);

  useEffect(() => {
    if (activeField) {
      Promise.all([
        fieldService.getFieldDashboard(activeField.id),
        advisoryService.getRecommendations(activeField.id)
      ]).then(([dashboard, recs]) => {
        setDashboardData({ sources: dashboard.sources, recommendations: recs });
      });
    }
  }, [activeField]);

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
