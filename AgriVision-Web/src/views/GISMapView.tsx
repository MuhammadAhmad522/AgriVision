import React, { useEffect, useRef, useState } from 'react';
import clsx from 'clsx';
import { useFleetStore, selectFilteredFields } from '../core/store/fleetStore';
import { useIoTStore } from '../core/store/iotStore';
import { useUIStore } from '../core/store/uiStore';
import * as maplibregl from 'maplibre-gl';
import { GISToolbar } from '../components/gis/GISToolbar';
import { GISInspectorDrawer } from '../components/gis/GISInspectorDrawer';
import { useMapLayers } from '../core/hooks/useMapLayers';

export const GISMapView: React.FC = () => {
  const fields = useFleetStore(selectFilteredFields);
  const activeField = useFleetStore(s => s.activeField);
  const setActiveField = useFleetStore(s => s.setActiveField);
  const sensors = useIoTStore(s => s.sensors);
  const fieldsRef = useRef(fields);

  useEffect(() => {
    fieldsRef.current = fields;
  }, [fields]);

  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<maplibregl.Map | null>(null);
  const [activeLayer, setActiveLayer] = useState<string>('satellite');
  const [mapLoaded, setMapLoaded] = useState(false);
  const [is3D, setIs3D] = useState(true);

  // Initialize MapLibre GL JS
  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    const map = new maplibregl.Map({
      container: mapContainerRef.current,
      style: {
        version: 8,
        sources: {
          'esri-satellite': {
            type: 'raster',
            tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
            tileSize: 256
          }
        },
        layers: [
          {
            id: 'satellite-layer',
            type: 'raster',
            source: 'esri-satellite',
            minzoom: 0,
            maxzoom: 22
          }
        ]
      },
      center: [74.3587, 31.5204],
      zoom: 12,
      pitch: 60,
      bearing: -10,
      attributionControl: false,
      maxPitch: 85,
      transformRequest: (url, resourceType) => {
        // If the URL is hitting our own backend for tiles, inject the Firebase JWT
        if (resourceType === 'Tile' && url.includes('/api/fields/')) {
          return (async () => {
            let token = '';
            try {
              const { auth } = await import('../core/auth/firebase');
              if (auth.currentUser) {
                token = await auth.currentUser.getIdToken();
              }
            } catch (e) {
              console.warn('Failed to fetch auth token for tile', e);
            }
            
            return {
              url,
              headers: token ? { 'Authorization': `Bearer ${token}` } : {}
            };
          })();
        }
        return { url };
      }
    });

    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), 'bottom-right');
    mapInstanceRef.current = map;

    const resizeObserver = new ResizeObserver(() => {
      map.resize();
    });
    resizeObserver.observe(mapContainerRef.current);

    map.on('load', () => {
      // Add 3D Terrain DEM source
      map.addSource('terrain', {
        type: 'raster-dem',
        tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
        encoding: 'terrarium',
        tileSize: 256,
        maxzoom: 15
      });
      map.setTerrain({ source: 'terrain', exaggeration: 1.2 });
      map.addControl(new maplibregl.TerrainControl({ source: 'terrain', exaggeration: 1.2 }), 'bottom-right');

      // Add source for fields GeoJSON
      map.addSource('fields', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] }
      });

      // Add fill layer for fields
      map.addLayer({
        id: 'fields-fill',
        type: 'fill',
        source: 'fields',
        paint: {
          'fill-color': ['get', 'color'],
          'fill-opacity': ['case', ['boolean', ['get', 'isActive'], false], 0.35, 0.15]
        }
      });

      // Add outline layer for fields
      map.addLayer({
        id: 'fields-outline',
        type: 'line',
        source: 'fields',
        paint: {
          'line-color': '#ffffff',
          'line-width': ['case', ['boolean', ['get', 'isActive'], false], 3, 1]
        }
      });

      // Add source for sensors
      map.addSource('sensors', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] }
      });

      // Add pulse halo for sensors
      map.addLayer({
        id: 'sensors-halo',
        type: 'circle',
        source: 'sensors',
        paint: {
          'circle-radius': 14,
          'circle-color': '#38bdf8',
          'circle-opacity': 0.3
        }
      });

      // Add solid core for sensors
      map.addLayer({
        id: 'sensors-core',
        type: 'circle',
        source: 'sensors',
        paint: {
          'circle-radius': 6,
          'circle-color': '#38bdf8',
          'circle-stroke-width': 2,
          'circle-stroke-color': '#ffffff'
        }
      });

      // Interactions
      map.on('click', 'fields-fill', (e: any) => {
        if (e.features && e.features.length > 0) {
          const fieldId = e.features[0].properties.id;
          const clickedField = fieldsRef.current.find(f => f.id === fieldId);
          if (clickedField) {
            setActiveField(clickedField);
            useUIStore.getState().setInspectorOpen(true);
          }
        }
      });

      map.on('click', (e) => {
        const features = map.queryRenderedFeatures(e.point, { layers: ['fields-fill'] });
        if (!features.length) {
          setActiveField(null);
        }
      });

      map.on('mouseenter', 'fields-fill', () => {
        map.getCanvas().style.cursor = 'pointer';
      });

      map.on('mouseleave', 'fields-fill', () => {
        map.getCanvas().style.cursor = '';
      });

      // Ensure canvas is resized correctly
      setTimeout(() => map.resize(), 100);

      setMapLoaded(true);
    });

    return () => {
      resizeObserver.disconnect();
      map.remove();
      mapInstanceRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Only run once for setup, handle updates separately

  const fitToAllFields = () => {
    if (!mapInstanceRef.current || !fieldsRef.current || fieldsRef.current.length === 0) return;
    
    const bounds = new maplibregl.LngLatBounds();
    let hasCoords = false;
    fieldsRef.current.forEach(f => {
      if (f.coordinates) {
        f.coordinates.forEach(c => {
          bounds.extend([c.lng ?? c.longitude ?? 0, c.lat ?? c.latitude ?? 0]);
          hasCoords = true;
        });
      }
    });

    if (hasCoords) {
      // Add significant right padding to ensure the 340px UI panel doesn't cover the fields
      mapInstanceRef.current.fitBounds(bounds, { padding: { top: 80, bottom: 80, left: 80, right: 400 }, duration: 1500, maxZoom: 14 });
    }
  };

  // Map layers and markers logic extracted to custom hook
  useMapLayers({
    mapInstance: mapInstanceRef,
    mapLoaded,
    fields,
    activeField,
    sensors,
    activeLayer,
    fitToAllFields
  });

  const toggle3D = () => {
    const map = mapInstanceRef.current;
    if (!map) return;
    if (is3D) {
      map.easeTo({ pitch: 0, bearing: 0, duration: 1000 });
      setIs3D(false);
    } else {
      map.easeTo({ pitch: 45, bearing: -10, duration: 1000 });
      setIs3D(true);
    }
  };

  const isInspectorOpen = useUIStore(s => s.isInspectorOpen);

  return (
    <div className="h-full flex relative overflow-hidden">
      <div 
        className={clsx(
          "flex-1 min-h-[400px] rounded-lg overflow-hidden relative border border-border-glass shadow-lg bg-[#111] transition-all duration-300",
          isInspectorOpen ? "md:mr-[340px]" : "mr-0"
        )}
      >
        {/* Map Container */}
        <div ref={mapContainerRef} style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, width: '100%', height: '100%' }} />
        
        <GISToolbar 
          activeLayer={activeLayer}
          setActiveLayer={setActiveLayer}
          is3D={is3D}
          toggle3D={toggle3D}
          fitToAllFields={fitToAllFields}
        />
      </div>

      <GISInspectorDrawer />
    </div>
  );
};
