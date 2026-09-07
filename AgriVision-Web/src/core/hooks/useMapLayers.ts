import { useEffect, useRef } from 'react';
import * as maplibregl from 'maplibre-gl';
import type { Field, SensorDevice } from '../types';

interface UseMapLayersOptions {
  mapInstance: React.MutableRefObject<maplibregl.Map | null>;
  mapLoaded: boolean;
  fields: Field[];
  activeField: Field | null;
  sensors: SensorDevice[];
  activeLayer: string;
  fitToAllFields: () => void;
}

export function useMapLayers({
  mapInstance,
  mapLoaded,
  fields,
  activeField,
  sensors,
  activeLayer,
  fitToAllFields
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
      
      const ndviColor = (f.ndvi_score || 0.7) > 0.7 ? '#568c48' : (f.ndvi_score || 0.7) > 0.4 ? '#fb923c' : '#f87171';
      
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
        el.className = 'px-2 py-1 rounded bg-black/60 text-white text-xs font-bold whitespace-nowrap shadow-md backdrop-blur-sm pointer-events-none border border-white/20';
        el.textContent = f.crop_type;
        
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
          color: ndviColor,
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
      
      // Toggle paint properties for 'clean 3D satellite view'
      if (activeLayer === 'satellite') {
        if (map.getLayer('fields-fill')) map.setPaintProperty('fields-fill', 'fill-opacity', 0.01);
        if (map.getLayer('fields-outline')) {
          map.setPaintProperty('fields-outline', 'line-dasharray', [1, 0]);
          map.setPaintProperty('fields-outline', 'line-opacity', ['case', ['boolean', ['get', 'isActive'], false], 1, 0.6]);
          map.setPaintProperty('fields-outline', 'line-color', '#f59e0b'); // Amber
          map.setPaintProperty('fields-outline', 'line-width', ['case', ['boolean', ['get', 'isActive'], false], 4, 2]);
        }
        if (map.getLayer('sensors')) map.setLayoutProperty('sensors', 'visibility', 'none');
      } else {
        if (map.getLayer('fields-fill')) map.setPaintProperty('fields-fill', 'fill-opacity', ['case', ['boolean', ['get', 'isActive'], false], 0.35, 0.15]);
        if (map.getLayer('fields-outline')) {
          map.setPaintProperty('fields-outline', 'line-dasharray', [1, 0]);
          map.setPaintProperty('fields-outline', 'line-opacity', ['case', ['boolean', ['get', 'isActive'], false], 1, 0.6]);
          map.setPaintProperty('fields-outline', 'line-color', '#f59e0b'); // Amber
          map.setPaintProperty('fields-outline', 'line-width', ['case', ['boolean', ['get', 'isActive'], false], 4, 2]);
        }
        if (map.getLayer('sensors')) map.setLayoutProperty('sensors', 'visibility', 'visible');
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
      if (activeLayer !== 'satellite') {
        const envUrl = import.meta.env.VITE_API_URL;
        const baseUrl = envUrl !== undefined ? envUrl : 'http://localhost:8000';
        map.addSource(sourceId, {
          type: 'raster',
          tiles: [`${baseUrl}/api/fields/${activeField.id}/satellite/latest/tile/${activeLayer}/{z}/{x}/{y}`],
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
  }, [activeField, activeLayer, mapLoaded, mapInstance]);

  // Update sensor markers
  useEffect(() => {
    const map = mapInstance.current;
    if (!map || !mapLoaded) return;

    const activeSensors = activeField ? sensors.filter(s => s.field_id === activeField.id) : sensors;
    
    const features = activeSensors.map(s => {
      let coord = [74.3587, 31.5204];
      if (activeField && activeField.coordinates.length > 0) {
        const first = activeField.coordinates[0];
        coord = [first.lng ?? first.longitude ?? 0, first.lat ?? first.latitude ?? 0];
      }
      return {
        type: 'Feature',
        properties: { id: s.id, name: s.name },
        geometry: { type: 'Point', coordinates: coord }
      };
    });

    const source = map.getSource('sensors') as maplibregl.GeoJSONSource;
    if (source) {
      source.setData({ type: 'FeatureCollection', features: features as any });
    }
  }, [sensors, activeField, mapLoaded, mapInstance]);
}
