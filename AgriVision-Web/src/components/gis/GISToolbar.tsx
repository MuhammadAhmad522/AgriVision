import React, { useState } from 'react';
import { Eye, Layers, Maximize, Cuboid, ChevronDown } from 'lucide-react';
import clsx from 'clsx';
import { useFleetStore } from '../../core/store/fleetStore';

interface GISToolbarProps {
  activeLayer: string;
  setActiveLayer: (layer: string) => void;
  is3D: boolean;
  toggle3D: () => void;
  fitToAllFields: () => void;
}

const RASTER_LAYERS = [
  { id: 'ndvi', name: 'NDVI (Plant Health)' },
  { id: 'evi', name: 'EVI (Enhanced Vegetation)' },
  { id: 'truecolor', name: 'True Color (RGB)' },
  { id: 'falsecolor', name: 'False Color (NIR)' },
];

export const GISToolbar: React.FC<GISToolbarProps> = ({ 
  activeLayer, 
  setActiveLayer, 
  is3D, 
  toggle3D, 
  fitToAllFields 
}) => {
  const activeField = useFleetStore(s => s.activeField);
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
                      "w-full text-left px-3 py-2 text-sm rounded-md transition-colors",
                      activeLayer === layer.id ? "bg-accent-orange/20 text-accent-orange" : "text-text-muted hover:bg-white/5 hover:text-white"
                    )}
                  >
                    {layer.name}
                  </button>
                ))}
              </div>
            </div>
          )}
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
