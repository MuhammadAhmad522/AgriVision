import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { sensorService } from '../services/SensorService';

/**
 * Hardware mutations. Each invalidates the shared `['sensors']` query rather than writing
 * into a store, so the fleet table, the analytics probe counter and the sidebar badge all
 * update from one refreshed cache entry.
 */

export function useSensorHealth(deviceId: string | undefined, enabled: boolean, hours = 24) {
  return useQuery({
    queryKey: ['sensor-health', deviceId, hours],
    queryFn: () => (deviceId ? sensorService.getDeviceHealth(deviceId, hours) : null),
    enabled: enabled && !!deviceId,
    staleTime: 30_000,
  });
}

export function usePairSensor() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ deviceId, ownerId }: { deviceId: string; ownerId?: string }) =>
      sensorService.pairSensor(deviceId, ownerId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['sensors'] }),
  });
}

export function useAssignSensor() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ fieldId, deviceId, name }: { fieldId: string; deviceId: string; name?: string }) =>
      sensorService.assignToField(fieldId, deviceId, name),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['sensors'] }),
  });
}

export function useDetachSensor() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ fieldId, deviceId }: { fieldId: string; deviceId: string }) =>
      sensorService.detachFromField(fieldId, deviceId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['sensors'] }),
  });
}

export function useUnpairSensor() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (deviceId: string) => sensorService.unpairSensor(deviceId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['sensors'] }),
  });
}

export function useVerifySensor() {
  return useMutation({
    mutationFn: (deviceId: string) => sensorService.verifySensor(deviceId),
  });
}
