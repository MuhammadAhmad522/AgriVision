import { useQuery } from '@tanstack/react-query';
import { sensorService } from '../services/SensorService';
import type { SensorReadingHourly } from '../types';

/**
 * Field telemetry shaped for charting.
 *
 * Three things this deliberately does not do, because the previous version did all three:
 *
 *  1. It does not invent a series. The soil chart used to plot a "10cm root-zone" line
 *     computed as `surface - 2.1`. There is one DS18B20 per node and no depth probe, so
 *     that line was arithmetic presented as a second sensor. The spread band below comes
 *     from the rollup's real min/max columns instead.
 *  2. It does not coerce missing readings to 0. `moisture_avg || 0` drew a telemetry gap
 *     as bone-dry soil — the one reading most likely to trigger an irrigation call.
 *     Gaps are null so the line breaks.
 *  3. It does not merge probes by accident. Rollup rows are per sensor per bucket, and
 *     they were mapped straight to points, so a field with two probes drew a zigzag
 *     alternating between them. Rows are now aggregated across sensors per bucket.
 */

export type AnalyticsRange = '24h' | '7d' | '30d';

interface RangeSpec {
  hours: number;
  granularity: 'hourly' | 'daily';
  limit: number;
  label: string;
  /** Bucket label format — hours within a day, dates across days. */
  timeFormat: 'time' | 'date';
}

export const ANALYTICS_RANGES: Record<AnalyticsRange, RangeSpec> = {
  '24h': { hours: 24, granularity: 'hourly', limit: 1000, label: 'Last 24 hours', timeFormat: 'time' },
  '7d': { hours: 168, granularity: 'hourly', limit: 1000, label: 'Last 7 days', timeFormat: 'date' },
  '30d': { hours: 720, granularity: 'daily', limit: 1000, label: 'Last 30 days', timeFormat: 'date' },
};

export const RANGE_OPTIONS: { id: AnalyticsRange; label: string }[] = [
  { id: '24h', label: '24h' },
  { id: '7d', label: '7d' },
  { id: '30d', label: '30d' },
];

export interface TelemetryPoint {
  /** Epoch ms, so the x-axis is a real time scale rather than a categorical string. */
  t: number;
  label: string;
  moisture: number | null;
  moistureMin: number | null;
  moistureMax: number | null;
  /** [min, max] for Recharts' band Area; null when the bucket has no moisture. */
  moistureBand: [number, number] | null;
  temperature: number | null;
  temperatureMin: number | null;
  temperatureMax: number | null;
  temperatureBand: [number, number] | null;
  readings: number;
  probes: number;
}

export interface NutrientReading {
  element: string;
  current: number;
  unit: string;
}

export interface AnalyticsResult {
  points: TelemetryPoint[];
  /** Which metrics the paired hardware actually reports, so the UI can hide the rest
   *  rather than charting zeros against invented agronomic targets. */
  hasMoisture: boolean;
  hasTemperature: boolean;
  hasNutrients: boolean;
  hasEc: boolean;
  hasPh: boolean;
  nutrients: NutrientReading[];
  latestEc: number | null;
  latestPh: number | null;
  /** Provenance: an agronomist should be able to see how much data is behind a line. */
  probeCount: number;
  readingCount: number;
  firstReadingAt: number | null;
  lastReadingAt: number | null;
  /** Buckets in the window that carry no reading at all. */
  gapCount: number;
  range: AnalyticsRange;
}

function num(value: number | null | undefined): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function mean(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function band(min: number | null, max: number | null): [number, number] | null {
  return min !== null && max !== null ? [min, max] : null;
}

function formatLabel(date: Date, format: RangeSpec['timeFormat']): string {
  return format === 'time'
    ? date.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
    : date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export function useAnalyticsData(fieldId: string | undefined, range: AnalyticsRange = '24h') {
  const spec = ANALYTICS_RANGES[range];

  return useQuery<AnalyticsResult | null>({
    queryKey: ['analytics', fieldId, range],
    queryFn: async () => {
      if (!fieldId) return null;

      const rows = await sensorService.getFieldReadings<SensorReadingHourly>(
        fieldId,
        spec.hours,
        spec.granularity,
        spec.limit
      );

      // Collapse per-sensor rows into one series per bucket: average the averages,
      // and take the true extremes across every probe reporting in that bucket.
      interface Accumulator {
        t: number;
        moistureAvgs: number[];
        moistureMin: number | null;
        moistureMax: number | null;
        tempAvgs: number[];
        tempMin: number | null;
        tempMax: number | null;
        readings: number;
        probes: Set<string>;
      }

      const buckets = new Map<number, Accumulator>();
      const probes = new Set<string>();
      const nutrientRows: SensorReadingHourly[] = [];

      for (const row of rows) {
        const t = new Date(row.bucket).getTime();
        if (Number.isNaN(t)) continue;

        if (row.sensor_id) probes.add(row.sensor_id);

        let acc = buckets.get(t);
        if (!acc) {
          acc = {
            t,
            moistureAvgs: [],
            moistureMin: null,
            moistureMax: null,
            tempAvgs: [],
            tempMin: null,
            tempMax: null,
            readings: 0,
            probes: new Set(),
          };
          buckets.set(t, acc);
        }

        const mAvg = num(row.moisture_avg);
        if (mAvg !== null) acc.moistureAvgs.push(mAvg);
        // Fall back to the average when a rollup lacks explicit extremes, so a single
        // reading in a bucket still produces a (zero-width) band rather than a hole.
        const mMin = num(row.moisture_min) ?? mAvg;
        const mMax = num(row.moisture_max) ?? mAvg;
        if (mMin !== null) acc.moistureMin = acc.moistureMin === null ? mMin : Math.min(acc.moistureMin, mMin);
        if (mMax !== null) acc.moistureMax = acc.moistureMax === null ? mMax : Math.max(acc.moistureMax, mMax);

        const tAvg = num(row.temperature_avg);
        if (tAvg !== null) acc.tempAvgs.push(tAvg);
        const tMin = num(row.temperature_min) ?? tAvg;
        const tMax = num(row.temperature_max) ?? tAvg;
        if (tMin !== null) acc.tempMin = acc.tempMin === null ? tMin : Math.min(acc.tempMin, tMin);
        if (tMax !== null) acc.tempMax = acc.tempMax === null ? tMax : Math.max(acc.tempMax, tMax);

        acc.readings += row.reading_count ?? 0;
        if (row.sensor_id) acc.probes.add(row.sensor_id);

        if (
          num(row.npk_n_avg) !== null ||
          num(row.npk_p_avg) !== null ||
          num(row.npk_k_avg) !== null ||
          num(row.ec_avg) !== null ||
          num(row.ph_avg) !== null
        ) {
          nutrientRows.push(row);
        }
      }

      const points: TelemetryPoint[] = Array.from(buckets.values())
        .sort((a, b) => a.t - b.t)
        .map((acc) => {
          const moisture = mean(acc.moistureAvgs);
          const temperature = mean(acc.tempAvgs);
          return {
            t: acc.t,
            label: formatLabel(new Date(acc.t), spec.timeFormat),
            moisture,
            moistureMin: acc.moistureMin,
            moistureMax: acc.moistureMax,
            moistureBand: band(acc.moistureMin, acc.moistureMax),
            temperature,
            temperatureMin: acc.tempMin,
            temperatureMax: acc.tempMax,
            temperatureBand: band(acc.tempMin, acc.tempMax),
            readings: acc.readings,
            probes: acc.probes.size,
          };
        });

      // Nutrients come from the most recent bucket that actually carried them; there is
      // no target column anywhere in the schema, so none is displayed.
      const latestNutrientRow = nutrientRows.length > 0
        ? nutrientRows.reduce((newest, row) =>
            new Date(row.bucket).getTime() > new Date(newest.bucket).getTime() ? row : newest
          )
        : null;

      const nutrients: NutrientReading[] = [];
      if (latestNutrientRow) {
        const n = num(latestNutrientRow.npk_n_avg);
        const p = num(latestNutrientRow.npk_p_avg);
        const k = num(latestNutrientRow.npk_k_avg);
        if (n !== null) nutrients.push({ element: 'Nitrogen (N)', current: n, unit: 'mg/kg' });
        if (p !== null) nutrients.push({ element: 'Phosphorus (P)', current: p, unit: 'mg/kg' });
        if (k !== null) nutrients.push({ element: 'Potassium (K)', current: k, unit: 'mg/kg' });
      }

      const withMoisture = points.filter((p) => p.moisture !== null);
      const withTemperature = points.filter((p) => p.temperature !== null);
      const withAny = points.filter((p) => p.moisture !== null || p.temperature !== null);

      return {
        points,
        hasMoisture: withMoisture.length > 0,
        hasTemperature: withTemperature.length > 0,
        hasNutrients: nutrients.length > 0,
        hasEc: latestNutrientRow ? num(latestNutrientRow.ec_avg) !== null : false,
        hasPh: latestNutrientRow ? num(latestNutrientRow.ph_avg) !== null : false,
        nutrients,
        latestEc: latestNutrientRow ? num(latestNutrientRow.ec_avg) : null,
        latestPh: latestNutrientRow ? num(latestNutrientRow.ph_avg) : null,
        probeCount: probes.size,
        readingCount: points.reduce((acc, p) => acc + p.readings, 0),
        firstReadingAt: withAny.length > 0 ? withAny[0].t : null,
        lastReadingAt: withAny.length > 0 ? withAny[withAny.length - 1].t : null,
        gapCount: points.length - withAny.length,
        range,
      };
    },
    enabled: !!fieldId,
    staleTime: 60_000,
    refetchInterval: 2 * 60 * 1000,
    refetchOnWindowFocus: true,
  });
}
