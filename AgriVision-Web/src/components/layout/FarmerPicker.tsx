import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Users, Search, Check, ChevronDown } from 'lucide-react';
import type { Client } from '../../core/store/fleetStore';
import { clientLabel } from '../../core/store/fleetStore';

interface Props {
  clients: Client[];
  activeClient: Client | null;
  onSelect: (client: Client | null) => void;
}

/** Header farmer selector with type-ahead search over name OR email. */
export const FarmerPicker: React.FC<Props> = ({ clients, activeClient, onSelect }) => {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const rootRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDocClick = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDocClick);
    document.addEventListener('keydown', onKey);
    // Focus the search box when the panel opens.
    const t = setTimeout(() => inputRef.current?.focus(), 0);
    return () => {
      document.removeEventListener('mousedown', onDocClick);
      document.removeEventListener('keydown', onKey);
      clearTimeout(t);
    };
  }, [open]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return clients;
    return clients.filter(
      (c) => (c.name || '').toLowerCase().includes(q) || (c.email || '').toLowerCase().includes(q)
    );
  }, [clients, query]);

  const choose = (c: Client | null) => {
    onSelect(c);
    setOpen(false);
    setQuery('');
  };

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="listbox"
        aria-expanded={open}
        className="flex items-center gap-2 bg-[rgba(22,51,30,0.7)] border border-border-glass px-2 md:px-3.5 py-2 rounded-md min-w-0 max-w-[240px] text-text-main font-heading font-bold text-xs md:text-sm outline-none hover:border-accent-cyan/50 transition-colors"
      >
        <Users size={16} className="text-accent-cyan shrink-0" />
        <span className="truncate">{activeClient ? clientLabel(activeClient) : 'All Farmers'}</span>
        <ChevronDown size={14} className="text-text-muted shrink-0 ml-auto" />
      </button>

      {open && (
        <div
          role="listbox"
          className="absolute left-0 top-[calc(100%+6px)] z-50 w-[280px] rounded-lg border border-border-glass bg-[#0e1f14] shadow-2xl backdrop-blur-md overflow-hidden"
        >
          <div className="flex items-center gap-2 px-3 py-2 border-b border-white/10">
            <Search size={14} className="text-text-dim shrink-0" />
            <input
              ref={inputRef}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              maxLength={120}
              placeholder="Search farmers by name or email…"
              className="w-full bg-transparent text-[13px] text-white placeholder:text-text-dim outline-none"
            />
          </div>

          <ul className="max-h-[300px] overflow-y-auto py-1">
            <li>
              <button
                type="button"
                onClick={() => choose(null)}
                className="w-full flex items-center gap-2 px-3 py-2 text-left text-[13px] text-text-main hover:bg-white/5 transition-colors"
              >
                <Check size={14} className={activeClient ? 'opacity-0' : 'text-accent-lime'} />
                All Farmers
              </button>
            </li>

            {filtered.map((c) => {
              const selected = activeClient?.id === c.id;
              return (
                <li key={c.id}>
                  <button
                    type="button"
                    onClick={() => choose(c)}
                    aria-selected={selected}
                    className="w-full flex items-start gap-2 px-3 py-2 text-left hover:bg-white/5 transition-colors"
                  >
                    <Check size={14} className={`mt-0.5 shrink-0 ${selected ? 'text-accent-lime' : 'opacity-0'}`} />
                    <span className="min-w-0">
                      <span className="block text-[13px] font-semibold text-text-main truncate">
                        {c.name?.trim() || c.email}
                      </span>
                      {c.name?.trim() && (
                        <span className="block text-[11px] text-text-muted truncate">{c.email}</span>
                      )}
                    </span>
                  </button>
                </li>
              );
            })}

            {filtered.length === 0 && (
              <li className="px-3 py-4 text-center text-[12px] text-text-dim italic">
                {clients.length === 0 ? 'No farmers yet.' : `No farmer matches “${query}”.`}
              </li>
            )}
          </ul>
        </div>
      )}
    </div>
  );
};
