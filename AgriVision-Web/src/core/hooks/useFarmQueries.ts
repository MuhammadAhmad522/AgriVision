import { useQuery } from '@tanstack/react-query';
import { useAuth } from '../auth/AuthContext';
import { fieldService } from '../services/FieldService';
import { sensorService } from '../services/SensorService';
import { advisoryService } from '../services/AdvisoryService';

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
  });
}
