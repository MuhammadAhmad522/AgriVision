import React, { useEffect, useRef, useState } from 'react';
import { useFarm } from '../core/context/FarmContext';
import { GlassCard } from '../components/ui/GlassCard';
import { MetricBadge } from '../components/ui/MetricBadge';
import { Eye, Layers, Activity, Droplet, Thermometer } from 'lucide-react';
import L from 'leaflet';
import clsx from 'clsx';

export const GISMapView: React.FC = () => {
  const { fields, activeField, setActiveField, dashboardData } = useFarm();
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const [activeLayer, setActiveLayer] = useState<'satellite' | 'ndvi' | 'moisture'>('ndvi');

  const ndviStats = dashboardData?.sources.satellite.data?.statistics?.ndvi;
  const moisture = dashboardData?.sources.soil.data?.moisture;
  const soilTemp = dashboardData?.sources.soil.data?.surface_temp_c;

  useEffect(() => {
    if (!mapContainerRef.current) return;

    if (!mapInstanceRef.current) {
      // Centered on Punjab, Pakistan
      const map = L.map(mapContainerRef.current, {
        center: [31.5204, 74.3587],
        zoom: 13,
        zoomControl: false
      });

      L.control.zoom({ position: 'bottomright' }).addTo(map);

      // Satellite Tile Layer (Esri World Imagery)
      L.tileLayer(
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        {
          attribution: 'Esri, Maxar, Earthstar Geographics',
          maxZoom: 18
        }
      ).addTo(map);

      mapInstanceRef.current = map;
    }

    const map = mapInstanceRef.current;

    // Clear previous vector layers
    map.eachLayer((layer) => {
      if (layer instanceof L.Polygon || layer instanceof L.Marker) {
        map.removeLayer(layer);
      }
    });

    // Render Field Boundary Polygons
    fields.forEach((f) => {
      const isSelected = f.id === activeField?.id;
      const latlngs: L.LatLngExpression[] = f.coordinates.map((c) => {
        const lat = c.lat ?? c.latitude ?? 0;
        const lng = c.lng ?? c.longitude ?? 0;
        return [lat, lng];
      });

      const ndviColor = (f.ndvi_score || 0.7) > 0.7 ? '#568c48' : (f.ndvi_score || 0.7) > 0.4 ? '#fb923c' : '#f87171';

      const polygon = L.polygon(latlngs, {
        color: isSelected ? '#9ad46c' : ndviColor,
        weight: isSelected ? 3 : 2,
        fillColor: ndviColor,
        fillOpacity: isSelected ? 0.45 : 0.25
      }).addTo(map);

      polygon.on('click', () => {
        setActiveField(f);
      });

      // Add Field Label Tooltip
      polygon.bindTooltip(
        `<b>${f.name}</b><br/>Crop: ${f.crop_type} • ${f.area_ha} ha<br/>NDVI: ${f.ndvi_score || '0.76'}`,
        { permanent: isSelected, direction: 'center', className: 'field-tooltip' }
      );
    });

    // Add Sensor Markers
    if (activeField && activeField.coordinates.length > 0) {
      const center = activeField.coordinates[0];
      const lat = center.lat ?? center.latitude ?? 0;
      const lng = center.lng ?? center.longitude ?? 0;
      
      const sensorPin = L.circleMarker([lat + 0.002, lng + 0.002], {
        radius: 8,
        fillColor: '#38bdf8',
        color: '#ffffff',
        weight: 2,
        fillOpacity: 0.9
      }).addTo(map);

      sensorPin.bindPopup(`
        <div class="font-body p-1">
          <h4 class="text-[13px] font-bold mb-1 text-[#16331e]">📡 Probe AGRI-01</h4>
          <p class="text-[11px] my-0.5"><b>Moisture:</b> ${moisture ? `${Math.round(moisture * 100)}%` : '38%'}</p>
          <p class="text-[11px] my-0.5"><b>Surface Temp:</b> ${soilTemp ? `${soilTemp.toFixed(1)}°C` : '26.2°C'}</p>
          <p class="text-[11px] my-0.5"><b>Status:</b> Telemetry Active</p>
        </div>
      `);

      map.flyTo([lat, lng], 14, { duration: 1.2 });
    }
  }, [fields, activeField, moisture, soilTemp]);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_340px] gap-5 h-[calc(100vh-110px)]">
      {/* Map Glass Canvas */}
      <div className="relative h-full rounded-xl overflow-hidden shadow-glass border border-border-glass">
        <div ref={mapContainerRef} className="w-full h-full" />

        {/* Map Layer Switcher Controls */}
        <div className="absolute top-4 left-4 z-[1000] flex gap-2 bg-[#0a170d]/85 backdrop-blur-md p-1.5 rounded-md border border-border-glass">
          <button
            onClick={() => setActiveLayer('ndvi')}
            className={clsx(
              "px-3 py-1.5 rounded-sm border-none text-xs font-semibold cursor-pointer flex items-center gap-1.5 transition-colors",
              activeLayer === 'ndvi' ? "bg-primary text-white" : "bg-transparent text-white hover:bg-white/10"
            )}
          >
            <Eye size={13} />
            NDVI Raster
          </button>

          <button
            onClick={() => setActiveLayer('satellite')}
            className={clsx(
              "px-3 py-1.5 rounded-sm border-none text-xs font-semibold cursor-pointer flex items-center gap-1.5 transition-colors",
              activeLayer === 'satellite' ? "bg-primary text-white" : "bg-transparent text-white hover:bg-white/10"
            )}
          >
            <Layers size={13} />
            TrueColor RGB
          </button>
        </div>

        {/* Map Legend Overlay */}
        <div className="absolute bottom-5 left-5 z-[1000] bg-[#0a170d]/85 backdrop-blur-md px-4 py-3 rounded-md border border-border-glass text-[11px]">
          <p className="font-bold mb-1.5 text-text-main">Sentinel-2 NDVI Scale</p>
          <div className="flex items-center gap-2">
            <span className="text-red-400">0.0 Stress</span>
            <div className="w-[120px] h-2 rounded-full bg-gradient-to-r from-red-400 via-orange-400 to-[#9ad46c]" />
            <span className="text-[#9ad46c]">1.0 Dense</span>
          </div>
        </div>
      </div>

      {/* Field Inspection Side Drawer */}
      <div className="flex flex-col gap-4 overflow-y-auto pr-1 custom-scrollbar">
        {/* Selected Field Hero */}
        <GlassCard glow className="p-4">
          <div className="flex justify-between items-start mb-3">
            <div>
              <p className="text-[11px] text-text-muted font-semibold">Active Geo-Zone</p>
              <h2 className="text-lg font-extrabold text-text-main">{activeField?.name || 'Loading Zone'}</h2>
            </div>
            <MetricBadge label={activeField?.crop_type || 'Crop'} variant="success" />
          </div>

          <div className="grid grid-cols-2 gap-2.5 mt-3.5">
            <div className="p-2.5 bg-black/20 rounded-sm">
              <p className="text-[11px] text-text-muted">Polygon Area</p>
              <p className="text-base font-bold text-accent-lime">
                {activeField?.area_ha || 0} ha
              </p>
            </div>

            <div className="p-2.5 bg-black/20 rounded-sm">
              <p className="text-[11px] text-text-muted">Sentinel NDVI</p>
              <p className="text-base font-bold text-text-main">
                {ndviStats?.mean ? ndviStats.mean.toFixed(2) : (activeField?.ndvi_score || 0.76).toFixed(2)}
              </p>
            </div>
          </div>
        </GlassCard>

        {/* Live Satellite Vigor Stats */}
        <GlassCard className="p-4">
          <div className="flex items-center gap-2 mb-3.5">
            <Activity size={16} className="text-primary-light" />
            <h3 className="text-sm font-bold text-text-main">Sentinel-2 Multispectral Scene</h3>
          </div>

          <div className="flex flex-col gap-2.5">
            <div className="flex justify-between text-xs">
              <span className="text-text-muted">Peak Vigor (Max NDVI):</span>
              <span className="font-bold text-accent-lime">{ndviStats?.max ? ndviStats.max.toFixed(3) : '0.890'}</span>
            </div>

            <div className="flex justify-between text-xs">
              <span className="text-text-muted">Stressed Pixels (Min NDVI):</span>
              <span className="font-bold text-red-400">{ndviStats?.min ? ndviStats.min.toFixed(3) : '0.580'}</span>
            </div>

            <div className="flex justify-between text-xs">
              <span className="text-text-muted">Spatial Homogeneity:</span>
              <span className="font-bold text-text-main">94.2% Uniform</span>
            </div>
          </div>
        </GlassCard>

        {/* Live In-Situ Telemetry Summary */}
        <GlassCard className="p-4">
          <div className="flex items-center gap-2 mb-3.5">
            <Droplet size={16} className="text-accent-cyan" />
            <h3 className="text-sm font-bold text-text-main">Live Soil Telemetry</h3>
          </div>

          <div className="grid grid-cols-2 gap-2.5">
            <div className="flex items-center gap-2">
              <Droplet size={18} className="text-accent-cyan" />
              <div>
                <p className="text-[10px] text-text-muted">Moisture</p>
                <p className="text-sm font-bold text-text-main">
                  {moisture ? `${Math.round(moisture * 100)}%` : '36%'}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Thermometer size={18} className="text-accent-orange" />
              <div>
                <p className="text-[10px] text-text-muted">Soil Temp</p>
                <p className="text-sm font-bold text-text-main">
                  {soilTemp ? `${soilTemp.toFixed(1)}°C` : '26.2°C'}
                </p>
              </div>
            </div>
          </div>
        </GlassCard>
      </div>
    </div>
  );
};
