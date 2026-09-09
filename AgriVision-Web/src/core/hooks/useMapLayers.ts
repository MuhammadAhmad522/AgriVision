import { useEffect, useRef } from 'react';
import * as maplibregl from 'maplibre-gl';
import type { DashboardPayload, Field, SensorDevice } from '../types';
import { healthPresentation } from '../utils/health';

interface UseMapLayersOptions {
  mapInstance: React.MutableRefObject<maplibregl.Map | null>;
  mapLoaded: boolean;
  fields: Field[];
  activeField: Field | null;
  sensors: SensorDevice[];
  activeLayer: string;
  fitToAllFields: () => void;
  /** Dashboard for the active field — carries the cache-busted raster tile templates. */
  dashboardData: DashboardPayload | null;
}

/** Centroid of a field's boundary, used to place labels and sensor pins. */
function fieldCentroid(field: Field): [number, number] | null {
  const points = (field.coordinates || [])
    .map((c) => [c.lng ?? c.longitude, c.lat ?? c.latitude])
    .filter((p): p is [number, number] => typeof p[0] === 'number' && typeof p[1] === 'number');
  if (points.length === 0) return null;
  const sum = points.reduce((acc, p) => [acc[0] + p[0], acc[1] + p[1]], [0, 0]);
  return [sum[0] / points.length, sum[1] / points.length];
}

export function useMapLayers({
  mapInstance,
  mapLoaded,
  fields,
  activeField,
  sensors,
  activeLayer,
  fitToAllFields,
  dashboardData
}: UseMapLayersOptions) {
  const markersRef = useRef<maplibregl.Marker[]>([]);

  // Update map data and markers when fields change
  useEffect(() => {
    const map = mapInstance.current;
    if (!map || !mapLoaded) return;

    // Clear old markers
    markersRef.current.forEach(m => m.remove());
    markersRef.current = [];

    const features = fields
      .filter(f => f.coordinates && f.coordinates.length >= 3)
      .map(f => {
      const coords = f.coordinates.map(c => [c.lng ?? c.longitude ?? 0, c.lat ?? c.latitude ?? 0]);
      if (coords.length > 0 && (coords[0][0] !== coords[coords.length-1][0] || coords[0][1] !== coords[coords.length-1][1])) {
         coords.push([...coords[0]]);
      }
      
      // Triage colour comes from the AI's holistic health score, not raw NDVI, and an
      // unscored field reads grey rather than green.
      const health = healthPresentation(f.latest_health_score);

      let minLng = coords[0][0], maxLng = coords[0][0];
      let minLat = coords[0][1], maxLat = coords[0][1];
      coords.forEach(c => {
        if (c[0] < minLng) minLng = c[0];
        if (c[0] > maxLng) maxLng = c[0];
        if (c[1] < minLat) minLat = c[1];
        if (c[1] > maxLat) maxLat = c[1];
      });
      const centerLng = (minLng + maxLng) / 2;
      const centerLat = (minLat + maxLat) / 2;

      // Create HTML marker for the crop label only if not in pure satellite mode
      if (activeLayer !== 'satellite') {
        const el = document.createElement('div');
        el.className = 'px-2 py-1 rounded bg-black/60 text-white text-xs font-bold whitespace-nowrap shadow-md backdrop-blur-sm pointer-events-none border border-white/20 flex items-center gap-1.5';
        const dot = document.createElement('span');
        dot.style.cssText = `width:7px;height:7px;border-radius:9999px;background:${health.color};display:inline-block;flex:none;`;
        const text = document.createElement('span');
        text.textContent = `${f.name} · ${health.label}`;
        el.appendChild(dot);
        el.appendChild(text);

        const marker = new maplibregl.Marker({ element: el })
          .setLngLat([centerLng, centerLat])
          .addTo(map);

        markersRef.current.push(marker);
      }

      return {
        type: 'Feature',
        properties: {
          id: f.id,
          name: f.name,
          crop: f.crop_type,
          color: health.color,
          isActive: f.id === activeField?.id
        },
        geometry: {
          type: 'Polygon',
          coordinates: [coords]
        }
      };
    });

    const source = map.getSource('fields') as maplibregl.GeoJSONSource;
    if (source) {
      source.setData({ type: 'FeatureCollection', features: features as any });
      
      // Auto-fit to all fields on initial load if no active field
      if (features.length > 0 && !activeField) {
        fitToAllFields();
      }
      
      // The health choropleth is the point of the fleet view, so it stays visible over
      // satellite imagery too — just lighter, so the underlying imagery is still readable.
      // Outlines carry the health colour in both modes rather than a fixed amber, so a
      // field's condition is legible at a glance without opening it.
      if (map.getLayer('fields-fill')) {
        map.setPaintProperty(
          'fields-fill',
          'fill-opacity',
          activeLayer === 'satellite'
            ? ['case', ['boolean', ['get', 'isActive'], false], 0.30, 0.18]
            : ['case', ['boolean', ['get', 'isActive'], false], 0.45, 0.28]
        );
      }
      if (map.getLayer('fields-outline')) {
        map.setPaintProperty('fields-outline', 'line-dasharray', [1, 0]);
        map.setPaintProperty('fields-outline', 'line-opacity', ['case', ['boolean', ['get', 'isActive'], false], 1, 0.75]);
        map.setPaintProperty('fields-outline', 'line-color', ['get', 'color']);
        map.setPaintProperty('fields-outline', 'line-width', ['case', ['boolean', ['get', 'isActive'], false], 4, 2]);
      }
      if (map.getLayer('sensors')) {
        map.setLayoutProperty('sensors', 'visibility', activeLayer === 'satellite' ? 'none' : 'visible');
      }
    }
  }, [fields, activeField, mapLoaded, fitToAllFields, mapInstance, activeLayer]);

  // Update Raster Tile Overlay and Fly to Active Field
  useEffect(() => {
    const map = mapInstance.current;
    if (!map || !mapLoaded) return;

    const sourceId = 'active-field-raster';
    const layerId = 'active-field-raster-layer';

    // Safely remove existing raster layer
    if (map.getLayer(layerId)) map.removeLayer(layerId);
    if (map.getSource(sourceId)) map.removeSource(sourceId);

    if (activeField && activeField.coordinates.length > 0) {
      // Fly to active field
      const coords = activeField.coordinates;
      const bounds = new maplibregl.LngLatBounds(
        [coords[0].lng ?? coords[0].longitude ?? 0, coords[0].lat ?? coords[0].latitude ?? 0],
        [coords[0].lng ?? coords[0].longitude ?? 0, coords[0].lat ?? coords[0].latitude ?? 0]
      );
      coords.forEach(c => bounds.extend([c.lng ?? c.longitude ?? 0, c.lat ?? c.latitude ?? 0]));
      
      // Right padding of 400px ensures the 340px Inspector Drawer doesn't cover the field
      map.fitBounds(bounds, { padding: { top: 80, bottom: 80, left: 80, right: 400 }, maxZoom: 16, duration: 1500 });

      // If not standard satellite, add raster source
      const satelliteData = dashboardData?.sources?.satellite?.data;
      const tileTemplate = activeLayer === 'ndvi' ? satelliteData?.ndvi_tile_url
        : activeLayer === 'ndwi' ? satelliteData?.ndwi_tile_url
        : activeLayer === 'evi' ? satelliteData?.evi_tile_url
        : activeLayer === 'truecolor' ? satelliteData?.truecolor_tile_url
        : undefined;

      if (activeLayer !== 'satellite' && tileTemplate) {
        const envUrl = import.meta.env.VITE_API_URL;
        const baseUrl = envUrl !== undefined ? envUrl : 'http://127.0.0.1:8000';
        // Template already includes the `?v=<scene timestamp>` cache-buster, so a newly
        // acquired scene actually replaces the previously cached tiles.
        map.addSource(sourceId, {
          type: 'raster',
          tiles: [`${baseUrl}${tileTemplate}`],
          tileSize: 256,
          maxzoom: 14,
          bounds: [bounds.getWest() - 0.05, bounds.getSouth() - 0.05, bounds.getEast() + 0.05, bounds.getNorth() + 0.05]
        });
        
        map.addLayer({
          id: layerId,
          type: 'raster',
          source: sourceId,
          paint: {
            'raster-opacity': 0.7,
            'raster-fade-duration': 500
          }
        }, 'fields-outline'); // Insert below outlines
      }
    }
  }, [activeField, activeLayer, mapLoaded, mapInstance, dashboardData]);

  // Update sensor markers
  useEffect(() => {
    const map = mapInstance.current;
    if (!map || !mapLoaded) return;

    // Sensors have no stored latitude/longitude, so an exact pin would be a fabricated
    // position. Until the hardware reports real coordinates, each sensor is drawn at the
    // centroid of the field it is assigned to — an honest "somewhere in this field" marker
    // rather than a false precise location on a boundary corner.
    const fieldsById = new Map(fields.map((f) => [f.id, f]));
    const activeSensors = (activeField ? sensors.filter(s => s.field_id === activeField.id) : sensors)
      .filter((s) => s.field_id && fieldsById.has(s.field_id));

    const features = activeSensors.flatMap(s => {
      const parent = fieldsById.get(s.field_id as string);
      const centroid = parent ? fieldCentroid(parent) : null;
      if (!centroid) return [];
      return [{
        type: 'Feature',
        properties: { id: s.id, name: s.name ?? s.device_id },
        geometry: { type: 'Point', coordinates: centroid }
      }];
    });

    const source = map.getSource('sensors') as maplibregl.GeoJSONSource;
    if (source) {
      source.setData({ type: 'FeatureCollection', features: features as any });
    }
  }, [sensors, fields, activeField, mapLoaded, mapInstance]);
}
