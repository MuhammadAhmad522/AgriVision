import React, { useEffect } from 'react';
import { useFields, useSensors, useDashboard } from '../hooks/useFarmQueries';
import { useFleetStore } from '../store/fleetStore';
import { useIoTStore } from '../store/iotStore';
import { useAuth } from '../auth/AuthContext';

export const FarmDataSync: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user } = useAuth();
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';

  const { setAllFields, setActiveField, activeField, setLoading } = useFleetStore();
  const { setSensors, setDashboardData, setLoadingDashboard } = useIoTStore();

  const fieldsQuery = useFields();
  const sensorsQuery = useSensors();
  const dashboardQuery = useDashboard(activeField?.id || null);

  // Sync fields
  useEffect(() => {
    if (fieldsQuery.data) {
      setAllFields(fieldsQuery.data);
      if (!isStaff && !activeField && fieldsQuery.data.length > 0) {
        setActiveField(fieldsQuery.data[0]);
      }
    }
  }, [fieldsQuery.data, setAllFields, isStaff, activeField, setActiveField]);

  // Sync sensors
  useEffect(() => {
    if (sensorsQuery.data) {
      setSensors(sensorsQuery.data);
    }
  }, [sensorsQuery.data, setSensors]);

  // Sync dashboard
  useEffect(() => {
    if (dashboardQuery.data) {
      setDashboardData(dashboardQuery.data);
    }
  }, [dashboardQuery.data, setDashboardData]);

  // Sync loading states
  useEffect(() => {
    setLoading(fieldsQuery.isLoading || sensorsQuery.isLoading);
  }, [fieldsQuery.isLoading, sensorsQuery.isLoading, setLoading]);

  useEffect(() => {
    setLoadingDashboard(dashboardQuery.isLoading);
  }, [dashboardQuery.isLoading, setLoadingDashboard]);

  return <>{children}</>;
};
