import { useQuery } from '@tanstack/react-query';
import { useAuth } from '../auth/AuthContext';
import { fieldService } from '../services/FieldService';
import { sensorService } from '../services/SensorService';
import { advisoryService } from '../services/AdvisoryService';

/**
 * Refresh policy. A command centre is left open on a wall or a second monitor, so these
 * queries refresh on their own and on window focus — previously nothing on this screen
 * revalidated after the first load, and an agronomist could act on hours-old telemetry
 * with nothing on screen suggesting it was old.
 */
const FIELD_REFRESH_MS = 5 * 60 * 1000;
const SENSOR_REFRESH_MS = 60 * 1000; // probe liveness is the fastest-moving of the three
const DASHBOARD_REFRESH_MS = 5 * 60 * 1000;

export function useFields() {
  const { user } = useAuth();
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';

  return useQuery({
    queryKey: ['fields', user?.uid],
    queryFn: async () => {
      if (!user) return [];
      return isStaff ? await fieldService.getAllFields() : await fieldService.getFields();
    },
    enabled: !!user,
    staleTime: 60_000,
    refetchInterval: FIELD_REFRESH_MS,
    refetchOnWindowFocus: true,
  });
}

export function useSensors() {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['sensors', user?.uid],
    queryFn: async () => {
      if (!user) return [];
      return await sensorService.getDevices();
    },
    enabled: !!user,
    staleTime: 30_000,
    refetchInterval: SENSOR_REFRESH_MS,
    refetchOnWindowFocus: true,
  });
}

export function useDashboard(fieldId: string | null) {
  return useQuery({
    queryKey: ['dashboard', fieldId],
    queryFn: async () => {
      if (!fieldId) return null;
      const [dashboard, recs] = await Promise.all([
        fieldService.getFieldDashboard(fieldId),
        advisoryService.getRecommendations(fieldId)
      ]);
      dashboard.recommendations = recs;
      return dashboard;
    },
    enabled: !!fieldId,
    staleTime: 60_000,
    refetchInterval: DASHBOARD_REFRESH_MS,
    refetchOnWindowFocus: true,
  });
}
