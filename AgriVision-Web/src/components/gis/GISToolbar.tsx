import React, { useState } from 'react';
import { Eye, Layers, Maximize, Cuboid, ChevronDown } from 'lucide-react';
import clsx from 'clsx';
import { useActiveField } from '../../core/hooks/useFleet';
import { HEALTH_LEGEND } from '../../core/utils/health';

interface GISToolbarProps {
  activeLayer: string;
  setActiveLayer: (layer: string) => void;
  is3D: boolean;
  toggle3D: () => void;
  fitToAllFields: () => void;
}

// Only layers the backend actually serves. "False Color (NIR)" was listed here but no such
// tile endpoint exists, so selecting it produced a blank overlay; NDWI is served and was
// missing from the list.
const RASTER_LAYERS = [
  { id: 'ndvi', name: 'NDVI (Plant Health)', hint: 'Canopy vigour' },
  { id: 'ndwi', name: 'NDWI (Water Stress)', hint: 'Moisture in the canopy' },
  { id: 'evi', name: 'EVI (Enhanced Vegetation)', hint: 'Vigour, less soil noise' },
  { id: 'truecolor', name: 'True Color (RGB)', hint: 'What the eye would see' },
];

export const GISToolbar: React.FC<GISToolbarProps> = ({ 
  activeLayer, 
  setActiveLayer, 
  is3D, 
  toggle3D, 
  fitToAllFields 
}) => {
  const activeField = useActiveField();
  const [dropdownOpen, setDropdownOpen] = useState(false);

  const activeRaster = RASTER_LAYERS.find(l => l.id === activeLayer);

  return (
    <>
      {/* Map Toolbars */}
      <div className="absolute top-4 left-4 z-10 flex gap-2 pointer-events-auto">
        <button 
          onClick={() => {
            setActiveLayer('satellite');
            setDropdownOpen(false);
          }}
          className={clsx('shadow-md', activeLayer === 'satellite' ? 'btn-primary' : 'btn-secondary !bg-[#1a3a23]/95 !border-[#1a3a23] hover:!bg-[#2d5c36]')}
        >
          <Eye size={16} /> Satellite
        </button>
        
        <div className="relative">
          <button 
            onClick={() => setDropdownOpen(!dropdownOpen)}
            disabled={!activeField}
            title={!activeField ? "Click on a field polygon on the map first" : "Raster Overlays"}
            className={clsx('shadow-md transition-all', activeLayer !== 'satellite' ? 'btn-primary' : 'btn-secondary !bg-[#1a3a23]/95 !border-[#1a3a23] hover:!bg-[#2d5c36]')}
          >
            <Layers size={16} /> 
            <span className="hidden md:inline">
              {!activeField ? 'Select a Field' : activeRaster ? activeRaster.name : 'Raster Layers'}
            </span>
            <ChevronDown size={14} className={clsx("transition-transform", dropdownOpen && "rotate-180")} />
          </button>

          {dropdownOpen && activeField && (
            <div className="absolute top-full left-0 mt-2 w-56 bg-[#0c1a11]/95 backdrop-blur-md border border-border-glass rounded-lg shadow-xl overflow-hidden animate-in fade-in slide-in-from-top-2">
              <div className="p-1">
                {RASTER_LAYERS.map(layer => (
                  <button
                    key={layer.id}
                    onClick={() => {
                      setActiveLayer(layer.id);
                      setDropdownOpen(false);
                    }}
                    className={clsx(
                      "w-full text-left px-3 py-2 rounded-md transition-colors",
                      activeLayer === layer.id ? "bg-accent-orange/20 text-accent-orange" : "text-text-muted hover:bg-white/5 hover:text-white"
                    )}
                  >
                    <span className="block text-sm">{layer.name}</span>
                    <span className="block text-[10px] opacity-70">{layer.hint}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Health legend — the polygon colours are a triage signal, so they need a key. */}
      <div className="absolute bottom-4 left-4 z-10 bg-[#0c1a11]/90 backdrop-blur-md border border-border-glass rounded-lg px-3 py-2.5 pointer-events-auto">
        <p className="text-[10px] font-bold text-text-main uppercase tracking-wide mb-1.5">Field health</p>
        <div className="flex flex-col gap-1">
          {HEALTH_LEGEND.map((entry) => (
            <div key={entry.band} className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: entry.color }} />
              <span className="text-[10px] text-text-muted whitespace-nowrap">{entry.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Floating Action Bar (Right side) */}
      <div className="absolute top-24 right-4 z-10 flex flex-col gap-2 pointer-events-auto">
        <button 
          onClick={fitToAllFields}
          className="w-10 h-10 rounded-full bg-[#1a3a23]/90 border border-border-glass shadow-lg text-text-muted hover:text-white flex items-center justify-center transition-colors"
          title="Fit to All Fields"
        >
          <Maximize size={18} />
        </button>
        <button 
          onClick={toggle3D}
          className={clsx("w-10 h-10 rounded-full border border-border-glass shadow-lg flex items-center justify-center transition-colors", is3D ? "bg-accent-lime text-[#112616]" : "bg-[#1a3a23]/90 text-text-muted hover:text-white")}
          title="Toggle 3D View"
        >
          <Cuboid size={18} />
        </button>
      </div>
    </>
  );
};
