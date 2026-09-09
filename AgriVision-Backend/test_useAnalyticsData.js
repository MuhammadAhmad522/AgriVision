// Mocking the behavior of useAnalyticsData.ts
const rows = [
  { bucket: '2026-09-08T10:00:00+00:00', moisture_avg: 27.530225, temperature_avg: 29.376822916666665, sensor_id: '0941e1f4-bcef-41c4-8df3-3671d9e3c931' },
  { bucket: '2026-09-08T09:00:00+00:00', moisture_avg: 49.375866168674726, temperature_avg: 29.9691852367688, sensor_id: '0941e1f4-bcef-41c4-8df3-3671d9e3c931' },
  { bucket: '2026-09-08T08:00:00+00:00', moisture_avg: null, temperature_avg: 29.39, sensor_id: '0941e1f4-bcef-41c4-8df3-3671d9e3c931' },
  { bucket: '2026-09-08T07:00:00+00:00', moisture_avg: null, temperature_avg: 28.857142857142858, sensor_id: '0941e1f4-bcef-41c4-8df3-3671d9e3c931' },
  { bucket: '2026-09-08T06:00:00+00:00', moisture_avg: null, temperature_avg: 28.86729074889868, sensor_id: '0941e1f4-bcef-41c4-8df3-3671d9e3c931' }
];

function num(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function mean(values) {
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function band(min, max) {
  return min !== null && max !== null ? [min, max] : null;
}

const buckets = new Map();
const probes = new Set();
const nutrientRows = [];

for (const row of rows) {
  const t = new Date(row.bucket).getTime();
  if (Number.isNaN(t)) continue;
  if (row.sensor_id) probes.add(row.sensor_id);
  
  let acc = buckets.get(t);
  if (!acc) {
    acc = { t, moistureAvgs: [], moistureMin: null, moistureMax: null, tempAvgs: [], tempMin: null, tempMax: null, readings: 0, probes: new Set() };
    buckets.set(t, acc);
  }
  
  const mAvg = num(row.moisture_avg);
  if (mAvg !== null) acc.moistureAvgs.push(mAvg);
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
}

const points = Array.from(buckets.values()).sort((a, b) => a.t - b.t).map((acc) => {
  const moisture = mean(acc.moistureAvgs);
  const temperature = mean(acc.tempAvgs);
  return {
    t: acc.t,
    moisture,
    moistureMin: acc.moistureMin,
    moistureMax: acc.moistureMax,
    moistureBand: band(acc.moistureMin, acc.moistureMax),
    temperature,
    temperatureMin: acc.tempMin,
    temperatureMax: acc.tempMax,
    temperatureBand: band(acc.tempMin, acc.tempMax),
  };
});

const withMoisture = points.filter((p) => p.moisture !== null);
console.log('hasMoisture:', withMoisture.length > 0);
console.log('points:', JSON.stringify(points, null, 2));
